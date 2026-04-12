locals {
  project_name = "eks-playground"
  cluster_name = "eks-playground-cluster"
  region       = data.aws_availability_zones.available.names[0]
}