# BOOTSTRAP

First-run ritual (do this on a fresh host or after a new image build):

1) Read docs: `docs/PHILOSOPHY.md`, `docs/ARCHITECTURE.md`, `docs/SHARED_MEMORY.md`, `docs/SECRETS.md`.
2) Read memory: `memory/project.md`, `memory/architecture.md`, `memory/ops.md`, `memory/discord.md`.
3) Record the live commit hashes in `memory/ops.md`:
   - `clawdinators`: `git -C /var/lib/clawd/repo rev-parse HEAD`
   - `nix-clawdbot`: `jq -r '.nodes["nix-clawdbot"].locked.rev' /var/lib/clawd/repo/flake.lock`
   - `nixpkgs`: `jq -r '.nodes["nixpkgs"].locked.rev' /var/lib/clawd/repo/flake.lock`
   - `clawdbot` (runtime): read `nix-clawdbot` lock in its repo or record the version from the service logs.
4) Verify secrets are present in `/run/agenix` and services are green:
   - `systemctl status clawdinator`
   - `systemctl status clawdinator-github-app-token`
   - `systemctl status clawdinator-self-update`
5) Send a Discord test message in `#clawdinators-test` and confirm a response.

Rule: If any step fails, fix it by changing code + rebuild (no manual host edits).
