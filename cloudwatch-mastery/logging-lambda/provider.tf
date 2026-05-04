terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.43.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "2.7.1"
    }
  }

  backend "s3" {
    bucket = "my-eks-tfstate-319829039858-ap-southeast-2" # tfstate bucket created to store states
    key    = "cloudwatch-mastery/logging-lambda/terraform.tfstate"
    region = "ap-southeast-2"
  }
}

provider "aws" {
  # Configuration options
  region = "ap-southeast-2"

    default_tags {
        tags = {
          Project = "LGLM"
        }
    }
}