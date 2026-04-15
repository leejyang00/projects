data "terraform_remote_state" "eks_playground" {
  backend = "s3"

  config = {
    bucket = "my-eks-tfstate-319829039858-ap-southeast-2"
    key    = "eks-playground/terraform.tfstate"
    region = "ap-southeast-2"
  }
}

data "terraform_remote_state" "infrastructure" {
  backend = "s3"

  config = {
    bucket = "my-eks-tfstate-319829039858-ap-southeast-2"
    key    = "infrastructure/terraform.tfstate"
    region = "ap-southeast-2"
  }
}