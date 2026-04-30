# Postmortem: Karpenter Node Not Registering — Missing aws-auth Entry

## Summary
Karpenter successfully provisioned an EC2 instance in response to a pending pod, but the node failed to register with the EKS cluster. The kubelet repeatedly received `Unauthorized` errors when attempting to contact the API server.

## Date
April 2026

## Severity
High — Karpenter nodes could not join the cluster, autoscaling was non-functional.

## Timeline
| Time | Event |
|------|-------|
| T+0  | Deployed busybox pod to test Karpenter |
| T+2m | Karpenter nominated pod, NodeClaim created |
| T+5m | EC2 instance launched in AWS (t3.small) |
| T+10m | NodeClaim status: `Node not registered with cluster` |
| T+15m | Connected to instance via SSM |
| T+20m | Found `Unauthorized` errors in kubelet logs |
| T+25m | Identified missing Karpenter node role in aws-auth |
| T+30m | Added role to aws-auth ConfigMap |
| T+35m | Node registered successfully |

## Root Cause
The `aws-auth` ConfigMap in the `kube-system` namespace only contained the IAM role for the existing managed node group. The Karpenter node role (`link-vault-dev-karpenter-node`) was not included, so when Karpenter-provisioned nodes attempted to authenticate with the API server, they were rejected with `Unauthorized`.

Kubelet logs on the node:
```
E kubelet_node_status.go:106] "Unable to register node with API server" 
err="Unauthorized" node="ip-10-0-89-113.ec2.internal"
```

## Impact
- All Karpenter-provisioned nodes failed to join the cluster
- Pending pods remained unscheduled
- EC2 instances were launched but unused, incurring cost

## Detection
```bash
# Check NodeClaim status
kubectl describe nodeclaim default-vqdc9

# SSH/SSM into the instance
aws ssm start-session --target <instance-id>
sudo journalctl -u kubelet -f
```

## Resolution
Added the Karpenter node role to the `aws-auth` ConfigMap:

```yaml
data:
  mapRoles: |
    - rolearn: arn:aws:iam::289296207513:role/link-vault-dev-node-role
      username: system:node:{{EC2PrivateDNSName}}
      groups:
      - system:bootstrappers
      - system:nodes
    - rolearn: arn:aws:iam::289296207513:role/link-vault-dev-karpenter-node
      username: system:node:{{EC2PrivateDNSName}}
      groups:
      - system:bootstrappers
      - system:nodes
```

## Lessons Learned
- Karpenter node role must be added to `aws-auth` before deploying Karpenter
- This is a prerequisite step often missing from quick-start guides
- Using EKS Access Entries (the newer API) instead of `aws-auth` would have been more manageable via Terraform

## Action Items
- [ ] Add aws-auth entry to Terraform EKS module as part of Karpenter setup
- [ ] Consider migrating from aws-auth ConfigMap to EKS Access Entries API
- [ ] Add Karpenter node registration verification to deployment runbook
