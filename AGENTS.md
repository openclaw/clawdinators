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
- Provision host with OpenTofu (`infra/opentofu`).
- Add host SSH key to agenix recipients and rekey secrets.
- Run `nixos-anywhere` with the flake host (ex: `.#clawdinator-1`).
- Set GitHub App `installationId` in host config (required).
- Configure Discord guild/channel allowlist in `services.clawdinator.config.discord`.
- Verify systemd services: `clawdinator`, `clawdinator-github-app-token`, `clawdinator-self-update`.
- Commit and push changes; repo is the source of truth.

Key principle: mental notes don’t survive restarts — write it to a file.
