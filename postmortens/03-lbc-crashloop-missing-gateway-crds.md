# Postmortem: LBC CrashLoopBackOff — Missing Gateway API CRDs

## Summary
After upgrading the AWS Load Balancer Controller to v3.2.0 and enabling the `ALBGatewayAPI` feature gate, the controller entered a CrashLoopBackOff state due to missing Gateway API CRDs from the experimental channel.

## Date
April 2026

## Severity
Critical — LBC was completely down, no load balancer operations possible.

## Timeline
| Time | Event |
|------|-------|
| T+0  | Upgraded LBC to v3.2.0 via Terraform Helm release |
| T+5m | LBC pods entered CrashLoopBackOff |
| T+10m | Investigated logs, found missing CRD errors |
| T+20m | Installed standard Gateway API CRDs — issue persisted |
| T+30m | Identified TCPRoute and UDPRoute as missing from experimental channel |
| T+40m | Installed experimental Gateway API CRDs |
| T+50m | LBC recovered and running |

## Root Cause
LBC v3.2.0 with Gateway API support requires CRDs from both the **standard** and **experimental** Gateway API channels. Specifically, `TCPRoute` and `UDPRoute` are only available in the experimental channel.

The standard install only provides:
- `GatewayClass`
- `Gateway`
- `HTTPRoute`

Missing from experimental channel:
- `TCPRoute`
- `UDPRoute`

Error observed:
```
"msg":"Disabling NLBGatewayAPI: missing required Gateway API CRDs",
"missing":["TCPRoute","UDPRoute"]
```

## Impact
- LBC completely unavailable
- No ALB operations possible
- Existing ALBs continued serving traffic but no changes could be made

## Detection
```bash
kubectl logs -n kube-system deployment/aws-load-balancer-controller --previous
```

## Resolution
Installed the experimental Gateway API CRDs:
```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/experimental-install.yaml
```

Then restarted the controller:
```bash
kubectl rollout restart deployment/aws-load-balancer-controller -n kube-system
```

## Lessons Learned
- Always check CRD requirements before upgrading controllers
- LBC v3.2.0+ requires experimental Gateway API channel when Gateway API is enabled
- Upgrade controllers in a staging environment first

## Action Items
- [ ] Add CRD pre-flight check to upgrade runbook
- [ ] Document required CRD channels in project README
- [ ] Add experimental CRDs installation to bootstrap Terraform module
