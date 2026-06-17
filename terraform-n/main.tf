###############################################################################
# Fleet of LXC containers that each host Docker + the Dockge stacks.
# Each mirrors the community-script "docker" CT: unprivileged Debian,
# nesting + keyctl enabled (required for Docker-in-LXC), DHCP on vmbr0.
###############################################################################

resource "proxmox_virtual_environment_container" "docker" {
  count = var.instance_count

  node_name     = var.node_name
  vm_id         = var.vmid != null ? var.vmid + count.index : null
  description   = "Docker host ${count.index} (managed by Terraform) — runs the div0-homelab-stack Dockge stacks."
  tags          = ["community-script", "docker", "terraform"]
  unprivileged  = true
  start_on_boot = true
  started       = true

  features {
    nesting = true
    keyctl  = true
  }

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory
    swap      = var.swap
  }

  disk {
    datastore_id = var.datastore_id
    size         = var.disk_size
  }

  operating_system {
    template_file_id = var.container_template
    type             = "debian"
  }

  network_interface {
    name   = "eth0"
    bridge = var.bridge
  }

  initialization {
    hostname = "${var.container_hostname}-${count.index}"

    # Set nameservers explicitly; the stock Debian template leaves resolv.conf
    # empty. Empty list = inherit the Proxmox host's DNS.
    dynamic "dns" {
      for_each = length(var.container_dns_servers) > 0 ? [1] : []
      content {
        servers = var.container_dns_servers
        domain  = var.container_search_domain != "" ? var.container_search_domain : null
      }
    }

    ip_config {
      ipv4 {
        address = var.ipv4_address
        gateway = var.ipv4_gateway != "" ? var.ipv4_gateway : null
      }
    }

    user_account {
      keys     = [local.ssh_public_key]
      password = var.container_password
    }
  }

  lifecycle {
    # The provider normalizes the injected SSH key, which would otherwise show a
    # perpetual diff.
    ignore_changes = [initialization[0].user_account[0].keys]
  }
}

locals {
  # eth0's IPv4 per instance, stripped of any CIDR suffix. The provider also
  # reports Docker bridge IPs (docker0, br-*) once Docker is installed, so select
  # eth0 by name. A per-index container_ip_override entry wins when set.
  container_ips = [
    for i, c in proxmox_virtual_environment_container.docker :
    length(var.container_ip_override) > i && var.container_ip_override[i] != "" ?
    var.container_ip_override[i] :
    split("/", lookup(c.ipv4, "eth0", ""))[0]
  ]
}
