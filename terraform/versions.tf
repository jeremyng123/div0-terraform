terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      # Modern, actively maintained Proxmox VE provider.
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
