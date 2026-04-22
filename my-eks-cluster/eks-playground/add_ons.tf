

# add ons:
# - coredns: cluster-internal DNS (service discovery)
# - kube-proxy: maintains iptables/IPVS rules on each node for Service routing
# - vpc-cni: assigns real VPC IPs to pods (AWS-specific networking)
# - eks-pod-identity-agent: enables EKS Pod Identity (replacement for IRSA) ??
# - external-dns: automatically creates Route53 records for Kubernetes services with LoadBalancer/Ingress
# - metrics-server: collects resource usage metrics for Horizontal Pod Autoscaler and kubectl top

# Resolve the default addon version AWS recommends for the cluster's K8s version.
# most_recent = false returns the DEFAULT version (safer); set true for newest.
data "aws_eks_addon_version" "coredns" {
  addon_name         = "coredns"
  kubernetes_version = aws_eks_cluster.eks_playground.version
  most_recent        = false
}

data "aws_eks_addon_version" "kube_proxy" {
  addon_name         = "kube-proxy"
  kubernetes_version = aws_eks_cluster.eks_playground.version
  most_recent        = false
}

data "aws_eks_addon_version" "vpc_cni" {
  addon_name         = "vpc-cni"
  kubernetes_version = aws_eks_cluster.eks_playground.version
  most_recent        = false
}

resource "aws_eks_addon" "coredns" {
  cluster_name  = aws_eks_cluster.eks_playground.name
  addon_name    = "coredns"
  addon_version = data.aws_eks_addon_version.coredns.version

  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.eks_playground_node_group]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = aws_eks_cluster.eks_playground.name
  addon_name    = "kube-proxy"
  addon_version = data.aws_eks_addon_version.kube_proxy.version

  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_cluster.eks_playground]
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = aws_eks_cluster.eks_playground.name
  addon_name    = "vpc-cni"
  addon_version = data.aws_eks_addon_version.vpc_cni.version

  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_cluster.eks_playground]
}
