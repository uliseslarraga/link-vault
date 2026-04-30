# Postmortem: kube-prometheus-stack Tolerations — kubeStateMetrics Key Mismatch

## Summary
After deploying the `kube-prometheus-stack` Helm chart, the `kube-state-metrics` pod remained in `Pending` state because tolerations were not applied. The issue was a mismatch between the camelCase key used in the parent chart values (`kubeStateMetrics`) and the actual subchart key (`kube-state-metrics`).

## Date
April 2026

## Severity
Medium — Observability stack partially unavailable, kube-state-metrics metrics not collected.

## Timeline
| Time | Event |
|------|-------|
| T+0  | kube-prometheus-stack deployed via ArgoCD |
| T+10m | Most pods running, `kube-state-metrics` stuck in Pending |
| T+20m | Verified node taints were the cause |
| T+30m | Added tolerations under `kubeStateMetrics` key — no effect |
| T+40m | Added tolerations under `kube-state-metrics` key — no effect |
| T+60m | Ran `helm show values` to inspect subchart structure |
| T+90m | Discovered subchart does not expose tolerations via parent |
| T+120m | Switched to separate `kube-state-metrics` Helm chart |
| T+130m | Pod scheduled correctly with tolerations |

## Root Cause
The `kube-prometheus-stack` chart embeds `kube-state-metrics` as a subchart. The subchart's tolerations are not fully exposed through the parent chart's values in all versions. Attempting to set tolerations via either `kubeStateMetrics.tolerations` (camelCase) or `kube-state-metrics.tolerations` (kebab-case) had no effect because the subchart did not pass these values through to the pod spec.

## Impact
- `kube-state-metrics` pod pending for 2+ hours
- Kubernetes object metrics unavailable in Prometheus
- Grafana dashboards showing incomplete data

## Detection
```bash
kubectl get pods -n monitoring -o wide
kubectl describe pod kube-monitoring-stack-kube-state-metrics -n monitoring
```

Events showed:
```
0/2 nodes are available: 2 node(s) had untolerated taint(s) {dedicated: system}
```

## Resolution
Disabled the embedded subchart and deployed `kube-state-metrics` as a standalone ArgoCD Application with explicit tolerations:

**In kube-prometheus-stack values:**
```yaml
kubeStateMetrics:
  enabled: false
```

**Standalone Application:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kube-state-metrics
  namespace: argocd
spec:
  source:
    repoURL: https://prometheus-community.github.io/helm-charts
    chart: kube-state-metrics
    targetRevision: "*"
    helm:
      valuesObject:
        tolerations:
        - key: dedicated
          operator: Equal
          value: system
          effect: NoSchedule
        nodeSelector:
          role: system
```

## Lessons Learned
- Subchart values may not be fully configurable through parent chart values
- Always run `helm show values <chart>` to understand the actual value structure before assuming pass-through works
- For complex multi-component charts with node taints, deploying subcharts independently gives more control

## Action Items
- [ ] Document subchart toleration limitations in project README
- [ ] Consider switching from `kube-prometheus-stack` to individual charts for better control
