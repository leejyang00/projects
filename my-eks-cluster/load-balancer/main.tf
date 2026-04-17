
locals {
  region      = "ap-southeast-2"
  oidc_issuer = replace(data.terraform_remote_state.eks_playground.outputs.eks_oidc_provider_url, "https://", "")
}

# IAM policy
resource "aws_iam_policy" "lb_controller" {
  name        = "${data.terraform_remote_state.eks_playground.outputs.eks_project_name}-lb-controller-policy"
  description = "IAM policy for AWS Load Balancer Controller in EKS cluster"

  policy = templatefile("${path.module}/lb-controller-policy.json.tftpl", {
    cluster_name = data.terraform_remote_state.eks_playground.outputs.eks_cluster_name
  })

  tags = {
    Name = "${data.terraform_remote_state.eks_playground.outputs.eks_project_name}-lb-controller-policy"
  }
}

# IAM role
resource "aws_iam_role" "lb_controller" {
  name = "${data.terraform_remote_state.eks_playground.outputs.eks_project_name}-lb-controller-role"

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
    Name = "${data.terraform_remote_state.eks_playground.outputs.eks_project_name}-lb-controller-role"
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

  set {
    name  = "clusterName"
    value = data.terraform_remote_state.eks_playground.outputs.eks_cluster_name
  }

  set {
    name  = "vpcId"
    value = data.terraform_remote_state.infrastructure.outputs.vpc_id
  }

  set {
    name  = "region"
    value = local.region
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.lb_controller.arn
  }

  wait = true

  depends_on = [
    aws_iam_role_policy_attachment.lb_controller_attachment
  ]
}
