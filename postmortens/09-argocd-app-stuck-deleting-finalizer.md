# Postmortem: ArgoCD Application Stuck Deleting — Finalizer Blocking Deletion

## Summary
An ArgoCD Application became stuck in a `Deleting` state indefinitely. A manually deleted Kubernetes Job (admission webhook hook) prevented the finalizer from completing, leaving the Application and all its child resources in a limbo state.

## Date
April 2026

## Severity
Medium — Application could not be recreated, blocking redeployment of the monitoring stack.

## Timeline
| Time | Event |
|------|-------|
| T+0  | Deleted ArgoCD Application to recreate with updated config |
| T+5m | Application stuck in `Deleting` state |
| T+10m | ArgoCD waiting for Job completion hook |
| T+15m | Identified manually deleted admission webhook Job |
| T+20m | Removed finalizer via kubectl patch |
| T+25m | Application deleted, namespace cleaned |
| T+30m | Redeployed successfully |

## Root Cause
The `kube-prometheus-stack` chart uses a Helm hook Job (`kube-admission-create`) to create admission webhooks for Prometheus Operator CRDs. When ArgoCD deletes an Application with `resources-finalizer.argocd.io`, it waits for all resources including hook Jobs to complete before removing the finalizer.

The Job had been manually deleted during troubleshooting, so ArgoCD was waiting for a resource that no longer existed — causing an infinite wait.

ArgoCD log:
```
waiting for completion of hook batch/Job/kube-monitoring-stack-kube-admission-create
```

## Impact
- ArgoCD Application stuck in Deleting for 30+ minutes
- Monitoring namespace resources could not be cleaned up
- Blocked redeployment of monitoring stack

## Detection
ArgoCD UI showed `Deleting` status with no progress. Checking the Application:
```bash
kubectl get application kube-monitoring-stack -n argocd -o yaml | grep -A5 finalizers
```

## Resolution
Forced deletion by removing the finalizer:
```bash
kubectl patch application kube-monitoring-stack -n argocd \
  --type merge \
  -p '{"metadata":{"finalizers":[]}}'
```

Then cleaned up orphaned resources:
```bash
kubectl delete all --all -n monitoring
kubectl delete namespace monitoring
```

## Lessons Learned
- Never manually delete Helm hook resources while ArgoCD is managing the Application
- If manual deletion is necessary during debugging, patch the finalizer immediately after
- The `resources-finalizer.argocd.io` finalizer is powerful — understand its implications before using it

## Break-Glass Procedure
When an ArgoCD Application is stuck deleting:
1. Identify what resource it's waiting for: check ArgoCD logs
2. If the resource is gone, patch the finalizer:
   ```bash
   kubectl patch application <name> -n argocd \
     --type merge \
     -p '{"metadata":{"finalizers":[]}}'
   ```
3. Clean up orphaned namespace resources manually

## Action Items
- [ ] Add break-glass procedure to runbook
- [ ] Document that Helm hook Jobs should never be manually deleted
- [ ] Consider using `finalizers: []` in non-production environments to speed up iteration
