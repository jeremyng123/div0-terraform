provider "proxmox" {
  endpoint = var.proxmox_endpoint
  insecure = var.proxmox_insecure

  # Auth: use root@pam username/password when a password is set, otherwise the
  # API token. Ticket (username/password) auth is REQUIRED to set LXC feature
  # flags other than `nesting` (e.g. keyctl) — API tokens get a 403 there.
  username  = var.proxmox_password != "" ? var.proxmox_username : null
  password  = var.proxmox_password != "" ? var.proxmox_password : null
  api_token = (var.proxmox_password == "" && var.proxmox_api_token != "") ? var.proxmox_api_token : null

  # bpg/proxmox falls back to SSH on the node for a handful of operations
  # (uploading files, some container customizations). Configure it so those
  # paths work even though container creation itself goes through the API.
  ssh {
    agent       = var.proxmox_ssh_agent
    username    = var.proxmox_node_ssh_username
    private_key = var.proxmox_node_ssh_private_key != "" ? var.proxmox_node_ssh_private_key : null
  }
}
