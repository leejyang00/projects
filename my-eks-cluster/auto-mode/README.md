# EKS Auto Mode Migration

## What we have now

**Terraform-managed:**

```
├── VPC (hand-rolled)
├── EKS Cluster (hand-rolled)
├── Managed Node Group + Launch Template + Node SG
├── Node IAM Role + 3 policy attachments
├── 4 EKS Add-ons (vpc-cni, kube-proxy, coredns, pod-identity)
├── LB Controller IAM Role + Policy
└── LB Controller Helm Release
```

**Kubernetes-managed:**

```
├── GatewayClass, Gateway, LoadBalancerConfiguration
├── 3 HTTPRoutes (website, echo, nginx)
├── 3 TargetGroupConfigurations
├── 3 Deployments + Services
└── ALB (created by Gateway)
```

## What Auto Mode replaces

| Remove from Terraform | Auto Mode handles it |
| --- | --- |
| Managed Node Group + Launch Template | Karpenter-based auto-scaling |
| Node IAM Role + 3 policies | Auto Mode node role (you create, simpler) |
| vpc-cni add-on | Built-in |
| kube-proxy add-on | Built-in |
| CoreDNS add-on | Built-in |
| Pod Identity Agent add-on | Built-in |
| LB Controller Helm Release | Built-in |
| LB Controller IAM Role + Policy | Built-in |
| Node SG | Managed by Auto Mode |

## What stays

| Resource | Change |
| --- | --- |
| VPC | unchanged |
| EKS Cluster resource | modified (add auto mode config) |
| OIDC Provider | stays (still useful for IRSA) |
| Access Entry | stays |
| Workloads (Deployments/Services) | unchanged |
| Gateway API CRDs | stay |
| HTTPRoutes | stay (re-point to new Gateway) |
| LoadBalancerConfiguration | stays |
| TargetGroupConfiguration | stays |

## Migration phases

1. **Phase 1** — Create Auto Mode node IAM role (Terraform).
2. **Phase 2** — Enable Auto Mode on cluster (Terraform).
   - Removes self-managed add-ons
   - Removes managed node group
   - Removes old LB controller
3. **Phase 3** — Auto Mode provisions new nodes; pods reschedule.
4. **Phase 4** — Create new Gateway (Auto Mode's built-in controller creates a new ALB).
   - Re-point HTTPRoutes
5. **Phase 5** — Delete old Gateway (destroys old ALB).
6. **Phase 6** — Clean up unused Terraform resources.

## Notes

**Downtime expectation:**

- Phases 2–3: ~5 minutes while pods reschedule.
- Phases 4–5: ~2–3 minutes during the ALB swap.

Acceptable for a lab environment.
