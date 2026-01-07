# OpenTofu (Hetzner)

This is the minimal, proven bootstrap: create a Hetzner host from a custom NixOS image.
No extra volumes, no fancy wiring.

Prereqs:
- OpenTofu >= 1.6
- Hetzner API token (use `HCLOUD_TOKEN` env var)
- Existing SSH key in Hetzner (set `ssh_key_name` to match)

Usage:
- export HCLOUD_TOKEN=...
- tofu init
- tofu apply

Inputs (defaults are sane for local dev):
- `name` (default: `clawdinator-1`)
- `server_type` (default: `cpx22`)
- `location` (default: `nbg1`)
- `ssh_key_name` (default: `clawdinator-deploy`)
- `image` (default: `clawdinator-nixos`)

Outputs:
- `server_name`
- `server_ipv4`

After apply, the machine boots directly into NixOS from the custom image. Then use the repo flake to configure it.
