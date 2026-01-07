variable "aws_region" {
  description = "AWS region for the image bucket."
  type        = string
}

variable "bucket_name" {
  description = "Existing S3 bucket name for image uploads."
  type        = string
  default     = "clawdinator-images-eu1-20260107165216"
}

variable "ci_user_name" {
  description = "Existing IAM user used by CI (keys already wired in GitHub)."
  type        = string
  default     = "clawdinator-image-uploader"
}

variable "tags" {
  description = "Tags to apply to AWS resources."
  type        = map(string)
  default     = {}
}
