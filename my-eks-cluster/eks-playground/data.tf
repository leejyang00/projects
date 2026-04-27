data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "terraform_remote_state" "infrastructure" {
  backend = "s3"

  config = {
    bucket = "my-eks-tfstate-319829039858-ap-southeast-2"
    key    = "infrastructure/terraform.tfstate"
    region = "ap-southeast-2"
  }
}

data "terraform_remote_state" "auto_mode" {
  backend = "s3"

  config = {
    bucket = "my-eks-tfstate-319829039858-ap-southeast-2"
    key    = "auto-mode/terraform.tfstate"
    region = "ap-southeast-2"
  }
}