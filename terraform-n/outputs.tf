output "container_ids" {
  description = "Proxmox container IDs, one per instance."
  value       = [for c in proxmox_virtual_environment_container.docker : c.vm_id]
}

output "container_ips" {
  description = "IPs the deploy provisioner connected to, one per instance."
  value       = local.container_ips
}

output "service_urls" {
  description = "Published service endpoints per instance (index 0 = docker-0, ...)."
  value = [
    for ip in local.container_ips : {
      dockge             = "http://${ip}:5001"
      grafana            = "http://${ip}:3000"
      dozzle             = "http://${ip}:8888"
      technitium_console = "http://${ip}:5380"
      mimir              = "http://${ip}:9090"
      loki               = "http://${ip}:3100"
      tempo              = "http://${ip}:3200"
      pyroscope          = "http://${ip}:4040"
      alloy              = "http://${ip}:12345"
    }
  ]
}
