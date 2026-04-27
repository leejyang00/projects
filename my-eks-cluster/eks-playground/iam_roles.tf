
# IAM roles for EKS cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks_cluster_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "eks.amazonaws.com"
        },
        Action = [
          "sts:AssumeRole",
          "sts:TagSession" 
        ]
      }
    ]
  })

  tags = {
    Environment = "dev"
    Project     = "eks-playground"
    ManagedBy   = "terraform"
    Component   = "eks-cluster"
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_role_attachment" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

####################### AUTO MODE - for cluster role #########################################
# Additional Cluster Role Policies for Auto Mode
#
# Your existing cluster role already has AmazonEKSClusterPolicy.
# Auto Mode needs 4 more policies so the EKS control plane can
# manage the capabilities it takes over from you.
#
# Without these, enabling Auto Mode will fail — the control plane
# won't have permission to provision nodes, create ALBs, etc.
################################################################################

resource "aws_iam_role_policy_attachment" "cluster_compute" {
  role = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"
}

resource "aws_iam_role_policy_attachment" "cluster_block_storage" {
  role = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy"
}

resource "aws_iam_role_policy_attachment" "cluster_load_balancing" {
  role = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
}

resource "aws_iam_role_policy_attachment" "cluster_networking" {
  role = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"
}

################################################################################
# IAM role for EKS worker nodes
# This role will be used by the worker nodes to interact with AWS services.
# It needs permissions to pull container images from ECR, manage network interfaces, etc.
##################################################################################
resource "aws_iam_role" "eks_node_role" {
  name = "eks_node_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = ["ec2.amazonaws.com"]
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_role_attachment" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_node_cni_attachment" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_node_ecr_attachment" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# create instance profile for node role (required for Auto Mode)
resource "aws_iam_role_policy" "cluster_create_instance_profile" {
  name = "AllowCreateInstanceProfileForAutoMode"
  role = aws_iam_role.eks_cluster_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "iam:CreateInstanceProfile",
        "iam:TagInstanceProfile",
        "iam:GetInstanceProfile",
        "iam:AddRoleToInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile",
        "iam:DeleteInstanceProfile"
      ]
      Resource = "arn:aws:iam::*:instance-profile/eks*"
    }]
  })
}

# Allow the cluster role to pass the Auto Mode node role to EC2 when
# launching nodes. AmazonEKSComputePolicy already grants this for roles
# tagged eks:eks-cluster-name=<cluster>, but pinning it explicitly avoids
# relying on the tag staying in place.
# resource "aws_iam_role_policy" "cluster_pass_node_role" {
#   name = "AllowPassAutoModeNodeRole"
#   role = aws_iam_role.eks_cluster_role.name

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect   = "Allow"
#       Action   = "iam:PassRole"
#       Resource = data.terraform_remote_state.auto_mode.outputs.auto_mode_node_role_arn
#       Condition = {
#         StringEquals = {
#           "iam:PassedToService" = "ec2.amazonaws.com"
#         }
#       }
#     }]
#   })
# }
