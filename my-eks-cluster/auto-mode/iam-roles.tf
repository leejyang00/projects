################################################################################
# Auto Mode Node Role
#
# This is the role that Auto Mode-provisioned EC2 instances assume.
# It's deliberately minimal — pods get their own IAM permissions via
# Pod Identity, so the node role only needs enough to:
#   - Register with the cluster (WorkerNodeMinimalPolicy)
#   - Pull container images from ECR (ContainerRegistryPullOnly)
#
# Compare with your current node role which has WorkerNodePolicy +
# CNI_Policy + ContainerRegistryReadOnly — all broader than needed.
################################################################################
resource "aws_iam_role" "eks_auto_mode_node_role" {
  name = "eks_auto_mode_node_role"

  # Trust policy must be ec2.amazonaws.com ONLY. Adding eks.amazonaws.com
  # causes EKS Auto Mode to reject the role with "UnauthorizedNodeRole".
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    "eks:eks-cluster-name" = "eks-playground-cluster"
  }
}

resource "aws_iam_role_policy_attachment" "eks_node_role_attachment" {
  role       = aws_iam_role.eks_auto_mode_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_node_ecr_attachment" {
  role       = aws_iam_role.eks_auto_mode_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

resource "aws_iam_role_policy_attachment" "eks_node_ecr_public_attachment" {
  role       = aws_iam_role.eks_auto_mode_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticContainerRegistryPublicReadOnly"
}

resource "aws_iam_role_policy_attachment" "eks_node_cni_attachment" {
  role       = aws_iam_role.eks_auto_mode_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

## Access Entry for creating custom node class
# For EKS Auto Mode with a custom NodeClass, the node role's access
# entry MUST be type "EC2" (not "EC2_LINUX" which is for self-managed
# nodes) AND must be associated with the AmazonEKSAutoNodePolicy.
# Without this, Karpenter reports: UnauthorizedNodeRole - "Role ... is
# unauthorized to join nodes to the cluster".
resource "aws_eks_access_entry" "auto_mode_node_access" {
  cluster_name  = data.terraform_remote_state.eks_playground.outputs.eks_cluster_name
  principal_arn = aws_iam_role.eks_auto_mode_node_role.arn
  type          = "EC2"
}

resource "aws_eks_access_policy_association" "auto_mode_node_access_policy" {
  cluster_name  = data.terraform_remote_state.eks_playground.outputs.eks_cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAutoNodePolicy"
  principal_arn = aws_iam_role.eks_auto_mode_node_role.arn

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.auto_mode_node_access]
}

## Instance profile for Auto Mode nodes
# This is needed if you want to use the same role for both Auto Mode and
# resource "aws_iam_instance_profile" "eks_auto_mode_node" {
#   name = "eks-auto-mode-node-profile"   # must start with "eks" to match policy
#   role = aws_iam_role.eks_auto_mode_node_role.name
# }