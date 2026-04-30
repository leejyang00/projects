# Dedicated security group for EKS worker nodes.
# Kept separate from the EKS-managed cluster SG so that:
#   1. The AWS LB Controller can add ALB → node ingress rules (it requires
#      the elbv2.k8s.aws/cluster tag to modify an SG).
#   2. The cluster SG stays untouched — only AWS manages it.

# resource "aws_security_group" "worker_node" {
#   name        = "${local.cluster_name}-node-sg"
#   description = "Security group for EKS worker nodes"

#   vpc_id = data.terraform_remote_state.infrastructure.outputs.vpc_id

#   tags = {
#     Name                                          = "${local.cluster_name}-node-sg"
#     "elbv2.k8s.aws/cluster"                       = local.cluster_name
#   }
# }

# # --- Ingress rules (least-privilege) ---

# resource "aws_vpc_security_group_ingress_rule" "node_to_node_tcp" {
#   security_group_id = aws_security_group.worker_node.id

#   referenced_security_group_id = aws_security_group.worker_node.id
#   from_port                    = 0
#   to_port                      = 65535
#   ip_protocol                  = "tcp"
#   description                  = "Node to node communication (kubelet, kube-proxy, pod-to-pod via CNI)"
# }

# resource "aws_vpc_security_group_ingress_rule" "node_to_node_udp" {
#   security_group_id = aws_security_group.worker_node.id

#   referenced_security_group_id = aws_security_group.worker_node.id
#   from_port                    = 0
#   to_port                      = 65535
#   ip_protocol                  = "udp"
#   description                  = "Node-to-node UDP (CoreDNS, CNI)"
# }

# # Control plane → nodes: API server talks to kubelet (10250),
# # webhooks, and extension APIs (1025-65535)
# resource "aws_vpc_security_group_ingress_rule" "control_plane_to_node" {
#   security_group_id            = aws_security_group.worker_node.id

#   referenced_security_group_id = aws_eks_cluster.eks_playground.vpc_config[0].cluster_security_group_id
#   from_port                    = 1025
#   to_port                      = 65535
#   ip_protocol                  = "tcp"
#   description                  = "Control plane to nodes (kubelet, webhooks)"
# }

# resource "aws_vpc_security_group_ingress_rule" "cluster_to_node" {
#   security_group_id = aws_security_group.worker_node.id

#   referenced_security_group_id = aws_eks_cluster.eks_playground.vpc_config[0].cluster_security_group_id
#   from_port                    = 443
#   to_port                      = 443
#   ip_protocol                  = "tcp"
#   description                  = "Control plane to node communication (kubelet/webhook)"
# }

# # --- Egress rules (least-privilege) ---

# # Nodes need outbound for: ECR image pulls, AWS APIs, DNS, NAT gateway
# resource "aws_vpc_security_group_egress_rule" "cluster_to_node" {
#   security_group_id = aws_security_group.worker_node.id

#   cidr_ipv4   = "0.0.0.0/0"
#   ip_protocol = "-1"
#   description = "Allow all outbound traffic from nodes (adjust as needed)"
# }

# # worker node launch template
# resource "aws_launch_template" "worker_node" {
#   name_prefix = "${local.cluster_name}-node-LT"

#   # Attach BOTH security groups:
#   #   - Cluster SG: control plane ↔ node (EKS-managed rules)
#   #   - Node SG: our custom rules + LB controller can add rules
#   vpc_security_group_ids = [
#     aws_security_group.worker_node.id,
#     aws_eks_cluster.eks_playground.vpc_config[0].cluster_security_group_id
#   ]

#   # Enforce IMDSv2 (security best practice)
#   metadata_options {
#     http_endpoint               = "enabled"
#     http_tokens                 = "required"
#     http_put_response_hop_limit = 2
#   }

#   tag_specifications {
#     resource_type = "instance"
#     tags = {
#       Name = "${local.cluster_name}-node"
#     }
#   }

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# # --- EKS node group ---
# resource "aws_eks_node_group" "eks_playground_node_group" {
#   cluster_name    = aws_eks_cluster.eks_playground.name
#   node_group_name = "eks-playground-node-group"
#   node_role_arn   = aws_iam_role.eks_node_role.arn
#   subnet_ids      = data.terraform_remote_state.infrastructure.outputs.private_subnet_ids

#   version = aws_eks_cluster.eks_playground.version

#   capacity_type = "SPOT" # Use "ON_DEMAND" for on-demand instances

#   scaling_config {
#     desired_size = 2
#     max_size     = 3
#     min_size     = 1
#   }

#   update_config {
#     max_unavailable = 1
#   }

#   launch_template {
#     id      = aws_launch_template.worker_node.id
#     version = aws_launch_template.worker_node.latest_version
#   }

#   instance_types = ["t3.small", "t3a.small"]
#   ami_type       = "AL2023_x86_64_STANDARD" # Use Amazon Linux 2023 AMI for EKS

#   # Labels applied to every node in this group
#   # Useful for nodeSelector/affinity when targeting workloads
#   labels = {
#     nodegroup = "default"
#     lifecycle = "spot"
#   }

#   depends_on = [
#     aws_iam_role_policy_attachment.eks_node_role_attachment,
#     aws_iam_role_policy_attachment.eks_node_cni_attachment,
#     aws_iam_role_policy_attachment.eks_node_ecr_attachment,
#   ]
# }
