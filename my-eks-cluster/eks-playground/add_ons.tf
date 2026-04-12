

# add ons:
# - coredns: cluster-internal DNS (service discovery)
# - kube-proxy: maintains iptables/IPVS rules on each node for Service routing
# - vpc-cni: assigns real VPC IPs to pods (AWS-specific networking)
# - eks-pod-identity-agent: enables EKS Pod Identity (replacement for IRSA) ??
# - external-dns: automatically creates Route53 records for Kubernetes services with LoadBalancer/Ingress
# - metrics-server: collects resource usage metrics for Horizontal Pod Autoscaler and kubectl top

###
# ran this command to find the latest addon versions compatible with Kubernetes 1.30:
# aws eks describe-addon-versions \
#   --kubernetes-version 1.30 \
#   --query 'addons[*].{Name:addonName, Versions:addonVersions[*].addonVersion}' \
#   --output table \
#   --addon-name coredns
###

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.eks_playground.name
  addon_name   = "coredns"
  addon_version = "v1.11.4-eksbuild.33" # matching cluster version 1.30"

#   depends_on = [aws_eks_cluster.eks_playground] # depends on node group

}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.eks_playground.name
  addon_name   = "kube-proxy"
  addon_version = "v1.30.14-eksbuild.28" # matching cluster version 1.30

  depends_on = [aws_eks_cluster.eks_playground]
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.eks_playground.name
  addon_name   = "vpc-cni"
  addon_version = "v1.21.1-eksbuild.1" # matching cluster version 1.30

  depends_on = [aws_eks_cluster.eks_playground]
}
