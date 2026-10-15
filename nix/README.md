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

Gateway packages use `meta.mainProgram` to select their executable when declared. Custom packages without this metadata retain the existing `bin/openclaw`, then `bin/moltbot` selection through a startup wrapper. Selection does not probe or realize the package during evaluation.

Test both direct startup and the token-loading wrapper with the locked nixpkgs and synthetic gateway packages:

```bash
nix-build nix/tests/gateway-executable.nix --option allow-import-from-derivation false --no-out-link
```

This checks argument and token forwarding for metadata-selected executables, metadata-free OpenClaw and legacy Moltbot packages, and a package containing both binaries (OpenClaw takes precedence), without deploying a host or contacting a provider.

The Pi package stays at 0.52.6 while its vendored dependency lockfile receives security updates. Its `basic-ftp` override fixes directory-listing parser denial of service in the FTP fallback used by `get-uri` and the proxy agent. Development-only audit findings in Pi's upstream test tools remain outside the installed runtime; updating those tools requires a separate upstream test migration.

Regenerate the lockfile from the published package's full `package.json`, preserving its upstream overrides and pinning the three Pi component dependencies to 0.52.6. Copying only the root lockfile metadata loses the upstream overrides and can leave dependencies missing from Nix's offline cache.

Build and test the packaged CLI and its FTP dependency without provider credentials:

```bash
nix-build nix/tests/pi-package.nix --no-out-link
```

This checks the CLI version, help, and model listing, a local FTP download through `get-uri`, and a hostile FTP directory listing under a process timeout.

Hosts:
- `nix/hosts/clawdinator-1.nix` is the first host config (templated; no machine-specific secrets)

Secrets:
- Explicit token files only: `discordTokenFile`, `anthropicApiKeyFile`, and either `githubPatFile` or `githubApp.*`.

Updates:
- Tracks `github:openclaw/nix-openclaw` (latest upstream)
- Self-update timer available via `services.clawdinator.selfUpdate.*`
