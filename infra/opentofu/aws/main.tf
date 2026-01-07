provider "aws" {
  region = var.aws_region
}

locals {
  suffix = var.bucket_suffix != "" ? var.bucket_suffix : random_id.bucket_suffix.hex
  name   = "${var.bucket_name}-${local.suffix}"
  tags   = merge(var.tags, { "app" = "clawdinator" })
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "image_bucket" {
  bucket = local.name
  tags   = local.tags
}

resource "aws_s3_bucket_public_access_block" "image_bucket" {
  bucket                  = aws_s3_bucket.image_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "image_bucket" {
  bucket = aws_s3_bucket.image_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "image_bucket" {
  bucket = aws_s3_bucket.image_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_iam_user" "image_uploader" {
  name = "clawdinator-image-uploader"
  tags = local.tags
}

resource "aws_iam_access_key" "image_uploader" {
  user = aws_iam_user.image_uploader.name
}

data "aws_iam_policy_document" "image_bucket_rw" {
  statement {
    sid = "ListBucket"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket"
    ]
    resources = [aws_s3_bucket.image_bucket.arn]
  }

  statement {
    sid = "ObjectReadWrite"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts"
    ]
    resources = ["${aws_s3_bucket.image_bucket.arn}/*"]
  }
}

resource "aws_iam_user_policy" "image_uploader" {
  name   = "clawdinator-image-bucket-rw"
  user   = aws_iam_user.image_uploader.name
  policy = data.aws_iam_policy_document.image_bucket_rw.json
}
