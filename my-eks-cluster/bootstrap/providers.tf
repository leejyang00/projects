terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.40.0"
    }
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
            Component   = "bootstrap"
        }
    }
}