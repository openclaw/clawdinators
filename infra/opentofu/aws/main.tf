provider "aws" {
  region = var.aws_region
}

locals {
  tags = merge(var.tags, { "app" = "clawdinator" })
}

data "aws_s3_bucket" "image_bucket" {
  bucket = var.bucket_name
}

data "aws_iam_policy_document" "vmimport_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vmie.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "vmimport" {
  name               = "vmimport"
  assume_role_policy = data.aws_iam_policy_document.vmimport_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "vmimport" {
  statement {
    actions = [
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      data.aws_s3_bucket.image_bucket.arn,
      "${data.aws_s3_bucket.image_bucket.arn}/*"
    ]
  }

  statement {
    actions = [
      "ec2:ModifySnapshotAttribute",
      "ec2:CopySnapshot",
      "ec2:RegisterImage",
      "ec2:Describe*"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "vmimport" {
  name   = "clawdinator-vmimport"
  role   = aws_iam_role.vmimport.id
  policy = data.aws_iam_policy_document.vmimport.json
}

data "aws_iam_user" "ci_user" {
  user_name = var.ci_user_name
}

data "aws_iam_policy_document" "ami_importer" {
  statement {
    sid = "ListBucket"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket"
    ]
    resources = [data.aws_s3_bucket.image_bucket.arn]
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
    resources = ["${data.aws_s3_bucket.image_bucket.arn}/*"]
  }

  statement {
    sid = "ImportImage"
    actions = [
      "ec2:ImportImage",
      "ec2:DescribeImportImageTasks",
      "ec2:DescribeImages",
      "ec2:CreateTags"
    ]
    resources = ["*"]
  }

  statement {
    sid = "PassVmImportRole"
    actions = ["iam:PassRole"]
    resources = [aws_iam_role.vmimport.arn]
  }
}

resource "aws_iam_user_policy" "ami_importer" {
  name   = "clawdinator-ami-importer"
  user   = data.aws_iam_user.ci_user.user_name
  policy = data.aws_iam_policy_document.ami_importer.json
}
