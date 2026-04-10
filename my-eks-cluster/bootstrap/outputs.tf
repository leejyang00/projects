output "my_eks_tfstate_bucket_name" {
  value       = aws_s3_bucket.my_eks_terraform_state.id
  description = "The name of the S3 bucket for Terraform remote state"
}

output "my_eks_tfstate_bucket_arn" {
  value       = aws_s3_bucket.my_eks_terraform_state.arn
  description = "The ARN of the S3 bucket for Terraform remote state"
}

