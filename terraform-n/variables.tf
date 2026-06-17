###############################################################################
# Proxmox connection
###############################################################################

variable "proxmox_endpoint" {
  description = "Proxmox VE API endpoint, e.g. https://pve.lan:8006/"
  type        = string
}

variable "proxmox_username" {
  description = "Proxmox user for ticket auth. Must be root@pam to set LXC feature flags like keyctl."
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Password for proxmox_username. Set this (root@pam) to use ticket auth; required for keyctl. Leave empty to use the API token instead."
  type        = string
  default     = ""
  sensitive   = true
}

variable "proxmox_api_token" {
  description = "API token 'user@realm!tokenid=uuid'. Used only when proxmox_password is empty. NOTE: tokens cannot set LXC feature flags other than nesting."
  type        = string
  default     = ""
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification (true for self-signed PVE certs)."
  type        = bool
  default     = true
}

variable "proxmox_ssh_agent" {
  description = "Use a local SSH agent for the provider's node SSH fallback."
  type        = bool
  default     = false
}

variable "proxmox_node_ssh_username" {
  description = "SSH user on the Proxmox node (for the provider's SSH fallback)."
  type        = string
  default     = "root"
}

variable "proxmox_node_ssh_private_key" {
  description = "PEM private key contents for node SSH. Leave empty to rely on the agent."
  type        = string
  default     = ""
  sensitive   = true
}

###############################################################################
# Fleet size
###############################################################################

variable "instance_count" {
  description = "How many identical docker LXC containers to create, each running Dockge + all stacks. Defaults to 2."
  type        = number
  default     = 2

  validation {
    condition     = var.instance_count >= 1
    error_message = "instance_count must be at least 1."
  }
}

###############################################################################
# LXC containers — each mirrors the existing 'docker' CT
###############################################################################

variable "node_name" {
  description = "Proxmox node to create the containers on."
  type        = string
  default     = "pve"
}

variable "vmid" {
  description = <<-EOT
    Base container ID. Leave null (the default) to let Proxmox auto-allocate the
    next free IDs. If set, instances are pinned to vmid, vmid+1, vmid+2, ... so
    make sure that whole range is free.
  EOT
  type        = number
  default     = null
}

variable "container_hostname" {
  description = "Base container hostname. Each instance gets '<hostname>-<index>' (docker-0, docker-1, ...)."
  type        = string
  default     = "docker"
}

variable "container_template" {
  description = <<-EOT
    Storage volume ID of the LXC template to build from, e.g.
    'local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst'.
    List available templates with `pveam available` / `pveam list local`.
  EOT
  type        = string
  default     = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
}

variable "cores" {
  description = "CPU cores per container."
  type        = number
  default     = 4
}

variable "memory" {
  description = "Dedicated memory in MiB per container."
  type        = number
  default     = 4096
}

variable "swap" {
  description = "Swap in MiB per container."
  type        = number
  default     = 512
}

variable "disk_size" {
  description = "Root filesystem size in GiB per container."
  type        = number
  default     = 100
}

variable "datastore_id" {
  description = "Storage for the container rootfs."
  type        = string
  default     = "local-lvm"
}

variable "bridge" {
  description = "Network bridge for eth0."
  type        = string
  default     = "vmbr0"
}

variable "ipv4_address" {
  description = "eth0 IPv4: 'dhcp' or a CIDR like '10.0.0.100/24'. A static CIDR is shared by every instance, so use 'dhcp' when instance_count > 1."
  type        = string
  default     = "dhcp"
}

variable "ipv4_gateway" {
  description = "Gateway when using a static ipv4_address. Empty for DHCP."
  type        = string
  default     = ""
}

variable "container_dns_servers" {
  description = "Nameservers written into the container's resolv.conf (needed because the stock Debian template doesn't inherit host DNS). Empty list = inherit host DNS. Use your LAN resolver if outbound public DNS is blocked."
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "container_search_domain" {
  description = "DNS search domain for the container. Empty to leave unset."
  type        = string
  default     = ""
}

variable "timezone" {
  description = "Timezone applied inside the containers."
  type        = string
  default     = "Asia/Singapore"
}

variable "container_password" {
  description = "Root password for the containers (console fallback)."
  type        = string
  sensitive   = true
}

variable "container_ip_override" {
  description = "Force the IP the provisioner connects to, per instance (e.g. [\"10.0.0.10\", \"10.0.0.11\"]). Index i overrides instance i; missing/empty entries fall back to DHCP auto-discovery."
  type        = list(string)
  default     = []
}

###############################################################################
# Dockge stacks
###############################################################################

variable "stacks_source_path" {
  description = "Local path to the managed Dockge stacks, copied into stacks_dest_path."
  type        = string
  default     = "../div0-homelab-stack/stacks"
}

variable "stacks_dest_path" {
  description = "Where the managed stacks land inside the container (Dockge's DOCKGE_STACKS_DIR)."
  type        = string
  default     = "/opt/stacks"
}

variable "dockge_source_path" {
  description = "Local path to Dockge's own compose, copied into dockge_dest_path."
  type        = string
  default     = "../div0-homelab-stack/dockge"
}

variable "dockge_dest_path" {
  description = "Where Dockge's own compose lands inside the container. Kept outside stacks_dest_path so Dockge does not manage itself."
  type        = string
  default     = "/opt/dockge"
}

variable "deploy_version" {
  description = "Bump this to force the stacks to redeploy (docker compose up -d)."
  type        = string
  default     = "1"
}

###############################################################################
# Stack secrets -> rendered into per-stack .env files
###############################################################################

### NOTE: password is used in plain string here. Exercise for div0:
###         - is it a danger?
###         - what can we do to avoid default passwords in our VCS?

variable "grafana_admin_user" {
  description = "Grafana admin username (lgtm-stack)."
  type        = string
  default     = "admin"
}

variable "grafana_admin_password" {
  description = "Grafana admin password (lgtm-stack)."
  type        = string
  sensitive   = true
  default     = "password"
}

variable "technitium_admin_password" {
  description = "Technitium DNS admin password."
  type        = string
  sensitive   = true
  default     = "password"
}

variable "technitium_api_token" {
  description = "Technitium API token used by the exporter and healthcheck."
  type        = string
  sensitive   = true
}
