###############################################################################
# Render secrets + bootstrap locally (gitignored), then push everything into
# each container and bring its stacks up. The rendered files are identical for
# every instance, so they are rendered once and reused by all deploys.
###############################################################################

resource "local_sensitive_file" "lgtm_env" {
  filename = "${path.module}/.rendered/lgtm-stack.env"
  content = templatefile("${path.module}/templates/lgtm.env.tftpl", {
    grafana_admin_user     = var.grafana_admin_user
    grafana_admin_password = var.grafana_admin_password
    technitium_api_token   = var.technitium_api_token
  })
}

resource "local_sensitive_file" "technitium_env" {
  filename = "${path.module}/.rendered/technitium.env"
  content = templatefile("${path.module}/templates/technitium.env.tftpl", {
    technitium_admin_password = var.technitium_admin_password
    technitium_api_token      = var.technitium_api_token
  })
}

resource "local_file" "bootstrap" {
  filename = "${path.module}/.rendered/bootstrap.sh"
  content = templatefile("${path.module}/templates/bootstrap.sh.tftpl", {
    stacks_dir  = var.stacks_dest_path
    dockge_dir  = var.dockge_dest_path
    timezone    = var.timezone
    dns_servers = join(" ", var.container_dns_servers)
  })
}

resource "terraform_data" "deploy_stacks" {
  count = var.instance_count

  # Replacing this resource re-runs the provisioners. It happens when the
  # matching container is recreated, a compose file or secret changes, the
  # bootstrap changes, or deploy_version is bumped.
  triggers_replace = {
    container_id   = proxmox_virtual_environment_container.docker[count.index].id
    deploy_version = var.deploy_version
    bootstrap_hash = sha1(local_file.bootstrap.content)
    secrets_hash = sha1(join("", [
      var.grafana_admin_user,
      var.grafana_admin_password,
      var.technitium_admin_password,
      var.technitium_api_token,
    ]))
    compose_hash = sha1(join("", concat(
      [for f in fileset(var.stacks_source_path, "**/compose.yaml") : filesha1("${var.stacks_source_path}/${f}")],
      [for f in fileset(var.dockge_source_path, "**/compose.yaml") : filesha1("${var.dockge_source_path}/${f}")],
    )))
  }

  connection {
    type        = "ssh"
    host        = local.container_ips[count.index]
    user        = "root"
    private_key = local.ssh_private_key
    timeout     = "4m"
  }

  # The file provisioner uploads into existing directories only.
  provisioner "remote-exec" {
    inline = ["mkdir -p ${var.stacks_dest_path} ${var.dockge_dest_path}"]
  }

  # Managed stacks -> /opt/stacks, Dockge -> /opt/dockge.
  provisioner "file" {
    source      = "${var.stacks_source_path}/"
    destination = var.stacks_dest_path
  }

  provisioner "file" {
    source      = "${var.dockge_source_path}/"
    destination = var.dockge_dest_path
  }

  # Rendered secrets, dropped beside their compose files.
  provisioner "file" {
    source      = local_sensitive_file.lgtm_env.filename
    destination = "${var.stacks_dest_path}/lgtm-stack/.env"
  }

  provisioner "file" {
    source      = local_sensitive_file.technitium_env.filename
    destination = "${var.stacks_dest_path}/technitium/.env"
  }

  # Install Docker, create the external networks, and bring every stack up.
  provisioner "file" {
    source      = local_file.bootstrap.filename
    destination = "/tmp/bootstrap.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/bootstrap.sh",
      "bash /tmp/bootstrap.sh",
    ]
  }
}
