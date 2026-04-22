

# aws eks cluster
resource "aws_eks_cluster" "eks_playground" {
    name = local.cluster_name
    role_arn = aws_iam_role.eks_cluster_role.arn
    version = "1.35"

    vpc_config {
        subnet_ids = concat(
            data.terraform_remote_state.infrastructure.outputs.private_subnet_ids,
            data.terraform_remote_state.infrastructure.outputs.public_subnet_ids
        )

        endpoint_private_access = true
        endpoint_public_access = true
        # public_access_cidrs = ["101.115.166.109/32"] # Replace with your IP or CIDR block for secure access
    }

    access_config {
        authentication_mode = "API_AND_CONFIG_MAP"
    }

    depends_on = [
        aws_iam_role_policy_attachment.eks_cluster_role_attachment
    ]
}

# cluster access entry
resource "aws_eks_access_entry" "admin_access" {
    cluster_name = aws_eks_cluster.eks_playground.name
    principal_arn = data.aws_caller_identity.current.arn
    type = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin_access_policy" {
    cluster_name = aws_eks_cluster.eks_playground.name
    policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
    principal_arn = data.aws_caller_identity.current.arn

    access_scope {
      type = "cluster"
    }

    depends_on = [ aws_eks_access_entry.admin_access ]
}

# fetch tls cert from OIDC issuer url
data "tls_certificate" "oidc" {
  url = aws_eks_cluster.eks_playground.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks_oidc_provider" {
  url = aws_eks_cluster.eks_playground.identity[0].oidc[0].issuer # https://oidc.eks.<region>.amazonaws.com/id/<eks-cluster-id>
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]
}
