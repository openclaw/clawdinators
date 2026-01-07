variable "aws_region" {
  description = "AWS region for the image bucket."
  type        = string
}

variable "bucket_name" {
  description = "Base name for the image bucket."
  type        = string
  default     = "clawdinator-images"
}

variable "bucket_suffix" {
  description = "Optional suffix to avoid naming collisions. If empty, a random suffix is used."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to AWS resources."
  type        = map(string)
  default     = {}
}
