terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.40.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }

  backend "s3" {
    bucket = "my-eks-tfstate-319829039858-ap-southeast-2" # tfstate bucket created to store states
    key    = "load-balancer/terraform.tfstate"
    region = "ap-southeast-2"
  }
}

provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.eks_playground.outputs.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.eks_playground.outputs.eks_certificate_authority)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks_playground.outputs.eks_cluster_name]
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
            Component   = "load-balancer"
        }
    }
}