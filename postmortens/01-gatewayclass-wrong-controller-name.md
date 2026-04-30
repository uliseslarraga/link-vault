# Postmortem: GatewayClass Wrong controllerName

## Summary
The GatewayClass resource was created with an incorrect `controllerName`, causing the AWS Load Balancer Controller to never accept or reconcile it. The Gateway remained in `Unknown` status indefinitely.

## Date
April 2026

## Severity
High — No ALB was provisioned, blocking all ingress traffic to the cluster.

## Timeline
| Time | Event |
|------|-------|
| T+0  | GatewayClass created with `controllerName: eks.amazonaws.com/alb` |
| T+10m | Gateway status remained `Unknown`, no ALB provisioned |
| T+20m | Investigated LBC logs, found controller identity |
| T+30m | Identified correct controllerName from logs |
| T+45m | Attempted in-place patch — failed, field is immutable |
| T+50m | Deleted and recreated GatewayClass with correct value |
| T+60m | Gateway accepted, ALB provisioning started |

## Root Cause
The `controllerName` field in the GatewayClass spec was set to `eks.amazonaws.com/alb`, which was the expected value based on older documentation. The AWS Load Balancer Controller v3.2.0 uses a different identity: `gateway.k8s.aws/alb`.

Since the controller only reconciles GatewayClass resources that match its own identity, the resource was silently ignored.

## Impact
- ALB was not provisioned
- ArgoCD UI was not accessible via external URL
- All Gateway-dependent HTTPRoutes were non-functional

## Detection
Manual investigation of LBC logs revealed the actual controller identity:
```
"controller":"gateway.k8s.aws/alb","source":"kind source: *v1.GatewayClass"
```

## Resolution
The `controllerName` field is immutable after creation. The GatewayClass had to be deleted and recreated with the correct value:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: aws-alb
spec:
  controllerName: gateway.k8s.aws/alb  # Correct value for LBC v3.2.0+
```

```bash
kubectl delete gatewayclass aws-alb
# ArgoCD recreated it automatically from Git
```

## Lessons Learned
- Always verify the controller identity from logs before creating a GatewayClass
- The `controllerName` field is immutable — plan carefully before applying
- Documentation may lag behind new controller versions

## Action Items
- [ ] Add a comment in the GatewayClass manifest noting the LBC version this was validated against
- [ ] Add a validation step in CI to verify GatewayClass status after apply
