# CLAWDINATOR Agent Notes

Read these before acting:
- docs/PHILOSOPHY.md
- docs/ARCHITECTURE.md
- docs/SHARED_MEMORY.md
- docs/SECRETS.md
- docs/POC.md

Memory references:
- For project goals, read memory/project.md
- For architecture decisions, read memory/architecture.md
- For ops runbook, read memory/ops.md
- For Discord context, also read memory/discord.md

Repo rule: no inline scripting languages (Python/Node/etc.) in Nix or shell blocks; put logic in script files and call them.

Deploy flow (automation-first):
- Use `devenv.nix` for tooling (hcloud, nixos-generators, zstd).
- Build a bootstrap NixOS image with nixos-generators (raw-efi), compress it, and upload to a public URL.
  - Use `nix/hosts/clawdinator-1-image.nix` for image builds.
- CI is preferred: `.github/workflows/image-build.yml` runs build → S3 upload → Hetzner import.
- Bootstrap S3 bucket + scoped IAM user with `infra/opentofu/aws` (use homelab-admin creds).
- Import the image into Hetzner with `hcloud image create`.
- Provision host with OpenTofu (`infra/opentofu`; set `HCLOUD_TOKEN`, no tfvars with secrets).
- Grab the host SSH key and add it to `../nix/nix-secrets/secrets.nix`; rekey secrets with agenix.
- Ensure required secrets exist: `clawdinator-github-app.pem`, `clawdinator-discord-token`, `anthropic-api-key`.
- Update `nix/hosts/<host>.nix` (Discord allowlist, GitHub App installationId, identity name).
- Ensure `/var/lib/clawd/repo` contains this repo (self-update requires it).
- Verify systemd services: `clawdinator`, `clawdinator-github-app-token`, `clawdinator-self-update`.
- Commit and push changes; repo is the source of truth.

Key principle: mental notes don’t survive restarts — write it to a file.

Cattle vs pets: hosts are disposable. Prefer re-provisioning from OpenTofu + NixOS configs over in-place manual fixes.
