output "bucket_name" {
  value = aws_s3_bucket.image_bucket.bucket
}

output "aws_region" {
  value = var.aws_region
}

output "ci_user_name" {
  value       = aws_iam_user.ci_user.name
  description = "IAM user expected to be wired in CI."
}

output "access_key_id" {
  value       = aws_iam_access_key.ci_user.id
  sensitive   = true
  description = "Use in CI as AWS_ACCESS_KEY_ID."
}

output "secret_access_key" {
  value       = aws_iam_access_key.ci_user.secret
  sensitive   = true
  description = "Use in CI as AWS_SECRET_ACCESS_KEY."
}

output "instance_id" {
  value       = local.instance_enabled ? aws_instance.clawdinator[0].id : null
  description = "CLAWDINATOR instance ID."
}

output "instance_public_ip" {
  value       = local.instance_enabled ? aws_instance.clawdinator[0].public_ip : null
  description = "CLAWDINATOR public IP."
}

output "instance_public_dns" {
  value       = local.instance_enabled ? aws_instance.clawdinator[0].public_dns : null
  description = "CLAWDINATOR public DNS."
}
