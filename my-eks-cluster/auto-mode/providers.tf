terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.40.0"
    }
  }

  backend "s3" {
    bucket = "my-eks-tfstate-319829039858-ap-southeast-2" # tfstate bucket created to store states
    key    = "auto-mode/terraform.tfstate"
    region = "ap-southeast-2"
  }
}

provider "aws" {
  # Configuration options
  region = "ap-southeast-2"

    default_tags {
        tags = {
            Project     = "eks-playground"
            ManagedBy   = "terraform"
            Environment = "dev"
            Component   = "auto-mode"
        }
    }
}