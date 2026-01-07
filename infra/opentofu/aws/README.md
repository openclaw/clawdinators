# OpenTofu (AWS S3 Image Bucket)

Goal: reuse the existing S3 bucket for CLAWDINATOR images, plus create the VM Import role and attach import permissions to the existing CI IAM user.

Prereqs:
- AWS credentials with permissions to manage IAM (use your homelab-admin key locally).

Usage:
- export AWS_ACCESS_KEY_ID=...
- export AWS_SECRET_ACCESS_KEY=...
- export AWS_REGION=us-east-1
- tofu init
- tofu apply

Outputs:
- `bucket_name` (existing)
- `aws_region`
- `ci_user_name` (existing IAM user)

CI wiring:
- Keep existing GitHub Actions secrets:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - `AWS_REGION`
  - `S3_BUCKET`
