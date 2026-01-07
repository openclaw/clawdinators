output "bucket_name" {
  value = data.aws_s3_bucket.image_bucket.bucket
}

output "aws_region" {
  value = var.aws_region
}

output "ci_user_name" {
  value       = data.aws_iam_user.ci_user.user_name
  description = "Existing IAM user expected to be wired in CI."
}
