# CLAWDINATOR Agent Notes

Read these before acting:
- docs/PHILOSOPHY.md
- docs/ARCHITECTURE.md
- docs/SHARED_MEMORY.md
- docs/SECRETS.md
- docs/POC.md
- BOOTSTRAP.md
- IDENTITY.md
- SOUL.md
- TOOLS.md
- USER.md

Memory references:
- For project goals, read memory/project.md
- For architecture decisions, read memory/architecture.md
- For ops runbook, read memory/ops.md
- For Discord context, also read memory/discord.md

Repo rule: no inline scripting languages (Python/Node/etc.) in Nix or shell blocks; put logic in script files and call them.

System ownership (3 repos):
- `clawdbot`: upstream runtime and behavior.
- `nix-clawdbot`: packaging/build fixes for `clawdbot`.
- `clawdinators`: infra, NixOS config, secrets wiring, deployment flow.

Maintainer role:
- Be proactive: file fixes, update docs, and reduce human toil.
- Track running versions (clawdbot/nix-clawdbot/clawdinators) and note them in `memory/ops.md`.

The Zen of ~~Python~~ Clawdbot, ~~by~~ shamelessly stolen from Tim Peters:
- Beautiful is better than ugly.
- Explicit is better than implicit.
- Simple is better than complex.
- Complex is better than complicated.
- Flat is better than nested.
- Sparse is better than dense.
- Readability counts.
- Special cases aren't special enough to break the rules.
- Although practicality beats purity.
- Errors should never pass silently.
- Unless explicitly silenced.
- In the face of ambiguity, refuse the temptation to guess.
- There should be one-- and preferably only one --obvious way to do it.
- Although that way may not be obvious at first unless you're Dutch.
- Now is better than never.
- Although never is often better than *right* now.
- If the implementation is hard to explain, it's a bad idea.
- If the implementation is easy to explain, it may be a good idea.
- Namespaces are one honking great idea -- let's do more of those!

Deploy flow (automation-first):
- Use `devenv.nix` for tooling (nixos-generators, awscli2).
- Build a bootstrap NixOS image with nixos-generators (raw) and upload it to S3.
  - Use `nix/hosts/clawdinator-1-image.nix` for image builds.
- CI is preferred: `.github/workflows/image-build.yml` runs build → S3 upload → AMI import.
- CI must provide `CLAWDINATOR_AGE_KEY` (private key) so the image can bake `/etc/agenix/keys/clawdinator.agekey`.
- Bootstrap S3 bucket + scoped IAM user + VM Import role with `infra/opentofu/aws` (use homelab-admin creds).
- Bootstrap AWS instances from the AMI with `infra/opentofu/aws` (set `TF_VAR_ami_id`).
- Import the image into AWS as an AMI (snapshot import + register image).
- Ensure secrets are encrypted to the baked agenix key (see `../nix/nix-secrets/secrets.nix`).
- Ensure required secrets exist: `clawdinator-github-app.pem`, `clawdinator-discord-token`, `clawdinator-anthropic-api-key`.
- Update `nix/hosts/<host>.nix` (Discord allowlist, GitHub App installationId, identity name).
- Ensure `/var/lib/clawd/repo` contains this repo (self-update requires it).
- Verify systemd services: `clawdinator`, `clawdinator-github-app-token`, `clawdinator-self-update`.
- Commit and push changes; repo is the source of truth.

Bootstrap (local):
- Agenix identity is `~/.ssh/id_ed25519` (primary SSH key).
- Decrypt homelab admin creds:
  - `RULES=../nix/nix-secrets/secrets.nix agenix -d homelab-admin.age -i ~/.ssh/id_ed25519`
- OpenTofu env:
  - `TF_VAR_aws_region=eu-central-1`
  - `TF_VAR_ami_id=ami-...` (empty string skips instance creation)
  - `TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"` (required when ami_id is set)
  - `TF_VAR_root_volume_size_gb=40` (bump if Nix store runs out of space)
- Run `tofu init` + `tofu apply` in `infra/opentofu/aws`.
- After apply, update CI secrets from outputs:
  - `tofu output -raw access_key_id` → `clawdinator-image-uploader-access-key-id.age`
  - `tofu output -raw secret_access_key` → `clawdinator-image-uploader-secret-access-key.age`
  - `tofu output -raw bucket_name` → `clawdinator-image-bucket-name.age`
  - `tofu output -raw aws_region` → `clawdinator-image-bucket-region.age`
  - Then `gh secret set` for `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `S3_BUCKET`.
- Get the latest AMI ID:
  - `aws ec2 describe-images --region eu-central-1 --owners self --filters "Name=tag:clawdinator,Values=true" --query "Images | sort_by(@,&CreationDate)[-1].[ImageId,Name,CreationDate]" --output text`
- If SSH access is lost, use SSM (instance profile is attached via OpenTofu) to re-add `/root/.ssh/authorized_keys`.

Key principle: mental notes don’t survive restarts — write it to a file.

Cattle vs pets: hosts are disposable. Prefer re-provisioning from OpenTofu + NixOS configs over in-place manual fixes.
One way only: AWS AMI pipeline via S3 + VM Import. This is a greenfield repo. Do not reference alternate paths anywhere in code or docs.
