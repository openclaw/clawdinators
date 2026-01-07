output "server_name" {
  value = hcloud_server.clawdinator.name
}

output "server_ipv4" {
  value = hcloud_server.clawdinator.ipv4_address
}
