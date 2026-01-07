# POC: CLAWDINATOR-1

Acceptance criteria:
- One Hetzner host provisioned via OpenTofu using a custom image.
- NixOS config applied via Nix (module or flake).
- CLAWDINATOR-1 connects to Discord #clawdributors-test.
- GitHub integration is read-only.
- Shared memory directory mounted and writable.
- Discord allowlist configured (guild + channels).

Secrets needed (initially):
- Discord bot token (per instance).
- GitHub token (PAT or App installation token).
- Anthropic API key.
- Hetzner API token.

Secrets wiring:
- Infra: HCLOUD_TOKEN env var for OpenTofu and hcloud CLI.
 
Image pipeline:
- Build a bootstrap image with nixos-generators (raw-efi) from `nix/hosts/clawdinator-1-image.nix`, compress, upload, import into Hetzner.
- OpenTofu provisions instances from the imported custom image, then nixos-rebuild applies full config.
- Runtime: explicit token files via agenix (standard).
- GitHub token is required. Prefer GitHub App (`services.clawdinator.githubApp.*`) to mint short-lived tokens.
- Store PEM and tokens in the local secrets repo (see docs/SECRETS.md) and decrypt to `/run/agenix/*`.
- Discord token is required: set `services.clawdinator.discordTokenFile` to `/run/agenix/clawdinator-discord-token`.

Deliverables:
- Infra code in infra/opentofu.
- Nix module in nix/.
- CLAWDINATOR config in clawdinator/.

Nix wiring notes:
- Apply nix-clawdbot overlay (latest upstream).
- Enable services.clawdinator and provide clawdbot.json config.
