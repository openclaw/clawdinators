output "bucket_name" {
  value = aws_s3_bucket.image_bucket.bucket
}

output "aws_region" {
  value = var.aws_region
}

output "access_key_id" {
  value       = aws_iam_access_key.image_uploader.id
  sensitive   = true
  description = "Use in CI as AWS_ACCESS_KEY_ID."
}

output "secret_access_key" {
  value       = aws_iam_access_key.image_uploader.secret
  sensitive   = true
  description = "Use in CI as AWS_SECRET_ACCESS_KEY."
}
