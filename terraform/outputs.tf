output "container_id" {
  description = "Proxmox container ID."
  value       = proxmox_virtual_environment_container.docker.vm_id
}

output "container_ip" {
  description = "IP the deploy provisioner connected to."
  value       = local.container_ip
}

output "service_urls" {
  description = "Published service endpoints (replace IP if using a hostname)."
  value = {
    dockge             = "http://${local.container_ip}:5001"
    grafana            = "http://${local.container_ip}:3000"
    dozzle             = "http://${local.container_ip}:8888"
    technitium_console = "http://${local.container_ip}:5380"
    mimir              = "http://${local.container_ip}:9090"
    loki               = "http://${local.container_ip}:3100"
    tempo              = "http://${local.container_ip}:3200"
    pyroscope          = "http://${local.container_ip}:4040"
    alloy              = "http://${local.container_ip}:12345"
  }
}
