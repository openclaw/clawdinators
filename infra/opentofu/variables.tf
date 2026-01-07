variable "hcloud_token" {
  description = "Hetzner API token. Prefer setting HCLOUD_TOKEN env var instead of tfvars."
  type        = string
  sensitive   = true
  default     = null
}

variable "ssh_key_name" {
  description = "Name of the existing Hetzner SSH key to attach."
  type        = string
  default     = "clawdinator-deploy"
}

variable "name" {
  description = "Server name."
  type        = string
  default     = "clawdinator-1"
}

variable "server_type" {
  description = "Hetzner server type."
  type        = string
  default     = "cpx22"
}

variable "image" {
  description = "Custom Hetzner image name or id (imported via hcloud)."
  type        = string
  default     = "clawdinator-nixos"
}

variable "location" {
  description = "Hetzner location (e.g., fsn1, nbg1, hel1)."
  type        = string
  default     = "nbg1"
}
