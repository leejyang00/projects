terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.40.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "4.2.1"
    }
  }

  backend "s3" {
    bucket = "my-eks-tfstate-319829039858-ap-southeast-2" # tfstate bucket created to store states
    key    = "eks-playground/terraform.tfstate"
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
            Component   = "eks-playground"
        }
    }
}

provider "tls" {
  # No configuration needed for TLS provider
}