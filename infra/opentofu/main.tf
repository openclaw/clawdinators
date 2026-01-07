provider "hcloud" {
  token = var.hcloud_token
}

data "hcloud_ssh_key" "deploy" {
  name = var.ssh_key_name
}

resource "hcloud_server" "clawdinator" {
  name        = var.name
  server_type = var.server_type
  image       = var.image
  location    = var.location
  ssh_keys    = [data.hcloud_ssh_key.deploy.id]
}
