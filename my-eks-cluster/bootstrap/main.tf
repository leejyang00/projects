
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# s3 bucket for storing Terraform remote state
resource "aws_s3_bucket" "my_eks_terraform_state" {
  bucket = format("my-eks-tfstate-%s-%s", data.aws_caller_identity.current.account_id, data.aws_region.current.name)

  tags = {
    Name        = "my-eks-tfstate-bucket"
  }
}

resource "aws_s3_bucket_versioning" "my_eks_terraform_state" {
  bucket = aws_s3_bucket.my_eks_terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "my_eks_terraform_state" {
  bucket = aws_s3_bucket.my_eks_terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "my_eks_terraform_state" {
  bucket = aws_s3_bucket.my_eks_terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    # bucket_key_enabled = true -- not supported with AES256, only with KMS keys
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "my_eks_terraform_state" {
  bucket = aws_s3_bucket.my_eks_terraform_state.id

  rule {
    id     = "ExpireOldVersions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}
