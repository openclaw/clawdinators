# CLAWDINATORS

CLAWDINATORS are maintainer‑grade coding agents. This repo defines how to spawn them
declaratively (OpenTofu + NixOS). Humans are not in the loop.

Principles:
- Declarative‑first. A CLAWDINATOR can bootstrap another CLAWDINATOR with a single command.
- No manual host edits. The repo + agenix secrets are the source of truth.
- Latest upstream nix‑clawdbot by default; breaking changes are acceptable.

Stack:
- Hetzner hosts provisioned with OpenTofu.
- NixOS modules configure Clawdbot and CLAWDINATOR runtime.
- Shared hive‑mind memory stored on a mounted host volume.

Shared memory (hive mind):
- All instances share the same memory files (no per‑instance prefixes for canonical files).
- Daily notes can be per‑instance: `YYYY-MM-DD_INSTANCE.md`.
- Canonical files are single shared sources of truth.

Example layout:
```
~/clawd/
├── memory/
│ ├── project.md # Project goals + non-negotiables
│ ├── architecture.md # Architecture decisions + invariants
│ ├── discord.md # Discord-specific stuff
│ ├── whatsapp.md # WhatsApp-specific stuff
│ └── 2026-01-06.md # Daily notes
```

Secrets (required):
- GitHub App private key (for short‑lived installation tokens).
- Discord bot token (per instance).
- Anthropic API key (Claude models).
- Hetzner API token (OpenTofu).

Secrets are stored in `../nix/nix-secrets` using agenix and decrypted to `/run/agenix/*`
on hosts. See `docs/SECRETS.md`.

Deploy (automation‑first):
- Prefer image-based provisioning for speed and repeatability.
- `infra/opentofu` provisions Hetzner hosts from a custom image.
- Host config lives in `nix/hosts/*` and is exposed in `flake.nix`.
- Ensure `/var/lib/clawd/repo` contains this repo (needed for self‑update).
- Configure Discord guild/channel allowlist and GitHub App installation ID.

Image-based deploy (Option A, recommended):
1) Build a bootstrap image with nixos-generators:
   - `nix run github:nix-community/nixos-generators -- -f raw-efi -c nix/hosts/clawdinator-1-image.nix -o dist`
2) Compress the image:
   - `zstd dist/nixos.img -o dist/nixos.img.zst`
3) Upload the image to S3 (private object; use a presigned URL for import).
4) Import into Hetzner:
   - `hcloud image create --from-url <url> --type custom --architecture x86 --name clawdinator-nixos`
5) Point OpenTofu at the image name or id and provision.
6) Re-key agenix secrets to the new host SSH key and sync secrets to `/var/lib/clawd/nix-secrets`.
7) Run `nixos-rebuild switch --flake /var/lib/clawd/repo#clawdinator-1`.

CI (recommended):
- GitHub Actions builds the image, uploads to S3, and imports into Hetzner.
- See `.github/workflows/image-build.yml` and `scripts/*.sh`.

AWS bucket bootstrap:
- `infra/opentofu/aws` provisions a private S3 bucket + scoped IAM user for CI uploads.

Docs:
- `docs/PHILOSOPHY.md`
- `docs/ARCHITECTURE.md`
- `docs/SHARED_MEMORY.md`
- `docs/POC.md`
- `docs/SECRETS.md`
- `docs/SKILLS_AUDIT.md`

Repo layout:
- `infra/opentofu` — Hetzner provisioning
- `nix/modules/clawdinator.nix` — NixOS module
- `nix/hosts/` — host configs
- `nix/examples/` — example host + flake wiring
- `memory/` — template memory files

Operating mode:
- No manual setup. Machines are created by automation (other CLAWDINATORS).
- Everything is in repo + agenix. No ad‑hoc changes on hosts.

## nix-clawdbot integration

Role: CLAWDINATORS own automation around packaging updates; `nix-clawdbot` stays focused on Nix packaging.

Automated flow:
1) Poll upstream clawdbot commits (throttled to max once every 10 minutes).
2) Update `nix-clawdbot` canary pin (PR).
3) Wait for Garnix build + `pnpm test`.
4) Run live Discord smoke test in `#clawdinators-test`.
5) If green → promote canary pin to stable (PR auto-merge).
6) If red → do nothing; stable stays pinned.
