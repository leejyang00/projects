
locals {
  region      = "ap-southeast-2"
  oidc_issuer = replace(data.terraform_remote_state.eks_playground.outputs.eks_oidc_provider_url, "https://", "")
}

# IAM policy
resource "aws_iam_policy" "lb_controller" {
  name        = data.terraform_remote_state.eks_playground.outputs.project_name + "-lb-controller-policy"
  description = "IAM policy for AWS Load Balancer Controller in EKS cluster"

  policy = file("${path.module}/lb-controller-policy.json")

  tags = {
    Name = "${data.terraform_remote_state.eks_playground.outputs.project_name}-lb-controller-policy"
  }
}

# IAM role
resource "aws_iam_role" "lb_controller" {
  name = data.terraform_remote_state.eks_playground.outputs.project_name + "-lb-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.terraform_remote_state.eks_playground.outputs.eks_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_issuer}:aud" = "sts.amazonaws.com"
            "${local.oidc_issuer}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${data.terraform_remote_state.eks_playground.outputs.project_name}-lb-controller-role"
  }
}

# IAM role policy attachment
resource "aws_iam_role_policy_attachment" "lb_controller_attachment" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.lb_controller.arn
}

# Load Balancer Controller - Helm Chart
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace = "kube-system"
  version   = "3.2.1"

  set = {
    "clusterName"       = data.terraform_remote_state.eks_playground.outputs.cluster_name
    "vpcId"             = data.terraform_remote_state.infrastructure.outputs.vpc_id
    "region"            = local.region
    "serviceAccount.create" = "true"
    "serviceAccount.name"   = "aws-load-balancer-controller"
    "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn" = aws_iam_role.lb_controller.arn
  }

  wait = true

  depends_on = [
    aws_iam_role_policy_attachment.lb_controller_attachment
  ]
}
