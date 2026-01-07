# OpenTofu (AWS S3 Image Bucket)

Goal: use the CLAWDINATOR S3 bucket for images, plus create the VM Import role and attach import permissions to the CI IAM user.

Prereqs:
- AWS credentials with permissions to manage IAM (use your homelab-admin key locally).

Usage:
- export AWS_ACCESS_KEY_ID=...
- export AWS_SECRET_ACCESS_KEY=...
- export AWS_REGION=eu-central-1
- export TF_VAR_aws_region=eu-central-1
- export TF_VAR_ami_id=ami-...   # leave empty to skip instance creation
- export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"   # required when ami_id is set
- tofu init
- tofu apply

Outputs:
- `bucket_name`
- `aws_region`
- `ci_user_name`
- `access_key_id`
- `secret_access_key`
- `instance_id`
- `instance_public_ip`
- `instance_public_dns`

CI wiring:
- Set GitHub Actions secrets:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - `AWS_REGION`
  - `S3_BUCKET`
