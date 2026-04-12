resource "aws_eks_node_group" "eks_playground_node_group" {
  cluster_name    = aws_eks_cluster.eks_playground.name
  node_group_name = "eks-playground-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = data.terraform_remote_state.infrastructure.outputs.private_subnet_ids

  capacity_type = "SPOT" # Use "ON_DEMAND" for on-demand instances

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  instance_types = ["t3.small", "t3a.small"]
  ami_type = "AL2023_x86_64_STANDARD" # Use Amazon Linux 2023 AMI for EKS

  # Labels applied to every node in this group
  # Useful for nodeSelector/affinity when targeting workloads
  labels = {
    nodegroup = "default"
    lifecycle = "spot"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_role_attachment,
    aws_iam_role_policy_attachment.eks_node_cni_attachment,
  ]
}
