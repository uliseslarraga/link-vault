# Postmortem: ALB Stuck in Unknown — Missing LoadBalancerConfiguration and TargetGroupConfiguration

## Summary
After fixing the GatewayClass and RBAC issues, the Gateway resource remained stuck in `Unknown/Pending` status. The root cause was that LBC v3.2.0 requires dedicated CRD objects for ALB and TargetGroup configuration instead of annotations.

## Date
April 2026

## Severity
High — ALB was not provisioned, no ingress traffic possible.

## Timeline
| Time | Event |
|------|-------|
| T+0  | Gateway created with ALB annotations |
| T+30m | Gateway stuck in Unknown, no ALB provisioned |
| T+60m | Investigated LBC logs, found TargetGroup port error |
| T+90m | Added `LoadBalancerConfiguration` CRD |
| T+100m | Error changed — progress confirmed |
| T+120m | Added `TargetGroupConfiguration` with correct spec |
| T+130m | ALB provisioning started |
| T+150m | ALB active, Gateway Programmed |

## Root Cause
LBC v3.2.0 introduced two new CRDs for Gateway API configuration:

1. **`LoadBalancerConfiguration`** — replaces ALB-level annotations (scheme, IP address type)
2. **`TargetGroupConfiguration`** — replaces target-type annotations (`ip` vs `instance`)

Using annotations alone was insufficient. Without `TargetGroupConfiguration` specifying `targetType: ip`, the controller defaulted to Instance mode and failed because ArgoCD Server uses a ClusterIP service.

Error observed:
```
"error":"TargetGroup port is empty. When using Instance targets, 
your service must be of type NodePort or LoadBalancer"
```

Additionally, the `targetType` field had to be nested under `defaultConfiguration`:
```yaml
# Wrong
spec:
  targetType: ip

# Correct
spec:
  defaultConfiguration:
    targetType: ip
```

## Impact
- No ALB provisioned for 2+ hours
- ArgoCD UI inaccessible externally
- All Gateway-dependent services blocked

## Detection
LBC logs:
```bash
kubectl logs -n kube-system deployment/aws-load-balancer-controller | grep -i "argocd-gateway\|error"
```

Gateway events:
```bash
kubectl describe gateway argocd-gateway -n argocd
```

## Resolution
Created two additional CRD objects:

**LoadBalancerConfiguration:**
```yaml
apiVersion: gateway.k8s.aws/v1beta1
kind: LoadBalancerConfiguration
metadata:
  name: argocd-lb-config
  namespace: argocd
spec:
  scheme: internet-facing
  ipAddressType: ipv4
```

**TargetGroupConfiguration:**
```yaml
apiVersion: gateway.k8s.aws/v1beta1
kind: TargetGroupConfiguration
metadata:
  name: argocd-tg-config
  namespace: argocd
spec:
  targetReference:
    name: argocd-server
    kind: Service
  defaultConfiguration:
    targetType: ip
    ipAddressType: ipv4
    protocol: HTTP
```

Referenced `LoadBalancerConfiguration` from Gateway via `infrastructure.parametersRef`.

## Lessons Learned
- LBC v3.2.0 Gateway API uses CRDs for configuration, not annotations
- Always use `kubectl explain <crd> --recursive` to discover the correct spec structure
- The `targetType` nesting under `defaultConfiguration` is not obvious from docs

## Action Items
- [ ] Document the full Gateway API object model in project README
- [ ] Add `kubectl explain` output for key CRDs to troubleshooting guide
