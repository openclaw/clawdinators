# Nix/NixOS

This directory holds Nix modules/flakes to configure CLAWDINATOR hosts.

References (local repos on the same machine):
- `../nix/ai-stack`
- `../nix/nixos-config`
- `../nix/nix-openclaw`

Responsibilities:
- Install and configure clawbot runtime
- Set up systemd services
- Mount /var/lib/clawd (shared memory)
- Inject secrets (Discord token, Anthropic key, GitHub token)

Module:
- `nix/modules/clawdinator.nix` provides `services.clawdinator`
- Example host config: `nix/examples/clawdinator-host.nix`
- Example flake wiring: `nix/examples/flake.nix`

Hosts:
- `nix/hosts/clawdinator-1.nix` is the first host config (templated; no machine-specific secrets)

Secrets:
- Explicit token files only: `discordTokenFile`, `anthropicApiKeyFile`, and either `githubPatFile` or `githubApp.*`.

Updates:
- Tracks `github:openclaw/nix-openclaw` (latest upstream)
- Self-update timer available via `services.clawdinator.selfUpdate.*`
