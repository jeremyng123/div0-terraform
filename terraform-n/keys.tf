###############################################################################
# SSH key for the container(s).
#
# Behaviour:
#   - If the public key file at var.ssh_public_key_path already exists, it is
#     read and used as-is (bring-your-own-key). The matching private key file is
#     used by the deploy provisioner.
#   - If it is missing, an ed25519 keypair is generated and written to the
#     configured paths, so subsequent runs reuse the same key.
#
# The generated keypair lives in Terraform state and is rendered with the `tls`
# provider rather than shelling out to `ssh-keygen`, because the key value is
# then available within the same apply (a file written mid-apply could not be
# read back at plan time).
###############################################################################

variable "ssh_public_key_path" {
  description = "Path to the SSH public key installed in the container(s). Generated here if missing."
  type        = string
  default     = "./.ssh/proxmox_homelab.pub"
}

variable "ssh_private_key_path" {
  description = "Path to the matching private key used by the deploy provisioner. Generated here if missing."
  type        = string
  default     = "./.ssh/proxmox_homelab"
}

locals {
  # try() makes a missing file read return "" instead of erroring at plan time.
  _existing_pub  = try(file(var.ssh_public_key_path), "")
  _existing_priv = try(file(var.ssh_private_key_path), "")

  # Reuse an existing key only when the public key file is actually present.
  use_existing_key = trimspace(local._existing_pub) != ""
}

# Generate a keypair only when no public key file exists yet.
resource "tls_private_key" "homelab" {
  count     = local.use_existing_key ? 0 : 1
  algorithm = "ED25519"
}

locals {
  # one(...) yields the generated value, or null when use_existing_key == true.
  _generated_pub  = one(tls_private_key.homelab[*].public_key_openssh)
  _generated_priv = one(tls_private_key.homelab[*].private_key_openssh)

  # Values handed to the container resource / provisioner.
  ssh_public_key  = trimspace(local.use_existing_key ? local._existing_pub : local._generated_pub)
  ssh_private_key = local.use_existing_key ? local._existing_priv : local._generated_priv

  # Exact bytes written to disk. For the bring-your-own case we write back the
  # file verbatim so there is never a perpetual diff; the resources are
  # unconditional so they are never destroyed (and so never delete the files).
  _pub_file_content  = local.use_existing_key ? local._existing_pub : "${local._generated_pub}\n"
  _priv_file_content = local.use_existing_key ? local._existing_priv : local._generated_priv
}

resource "local_file" "ssh_public_key" {
  filename        = var.ssh_public_key_path
  content         = local._pub_file_content
  file_permission = "0644"
}

resource "local_sensitive_file" "ssh_private_key" {
  filename        = var.ssh_private_key_path
  content         = local._priv_file_content
  file_permission = "0600"
}
