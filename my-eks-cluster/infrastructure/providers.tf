terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.40.0"
    }
  }

  backend "s3" {
    bucket = "my-eks-tfstate-319829039858-ap-southeast-2" # tfstate bucket created to store states
    key    = "infrastructure/terraform.tfstate"
    region = "ap-southeast-2"
  }
}

provider "aws" {
  # Configuration options
  region = "ap-southeast-2"

    default_tags {
        tags = {
            Project     = "my-eks-cluster"
            ManagedBy   = "terraform"
            Environment = "dev"
            Component   = "infrastructure"
        }
    }
}