# Postmortem: LBC Missing RBAC for ListenerSets

## Summary
After enabling the `ALBGatewayAPI` feature gate in the AWS Load Balancer Controller, the controller began throwing continuous RBAC errors for `listenersets.gateway.networking.k8s.io`. The controller was unable to watch this resource, preventing Gateway reconciliation.

## Date
April 2026

## Severity
High — Gateway API reconciliation was blocked, no ALB could be provisioned.

## Timeline
| Time | Event |
|------|-------|
| T+0  | Enabled `ALBGatewayAPI: true` feature gate in LBC Helm values |
| T+5m | LBC pods restarted successfully |
| T+10m | Continuous RBAC errors appeared in controller logs |
| T+20m | Identified missing ClusterRole for `listenersets` resource |
| T+30m | Created RBAC manifests and pushed to Git |
| T+40m | ArgoCD synced, LBC restarted, errors resolved |

## Root Cause
The AWS Load Balancer Controller v3.2.0 with Gateway API enabled requires permissions to list and watch `listenersets.gateway.networking.k8s.io`. The default Helm chart ClusterRole did not include this permission, and the new Gateway API CRDs introduced this resource without a corresponding RBAC update.

Error observed:
```json
{
  "error": "failed to list *v1.ListenerSet: listenersets.gateway.networking.k8s.io 
  is forbidden: User system:serviceaccount:kube-system:aws-load-balancer-controller 
  cannot list resource listenersets in API group gateway.networking.k8s.io 
  at the cluster scope"
}
```

## Impact
- Gateway API reconciliation loop was broken
- Continuous error logs flooding CloudWatch
- No ALB provisioning possible

## Detection
Reviewing LBC logs after enabling the feature gate:
```bash
kubectl logs -n kube-system deployment/aws-load-balancer-controller | grep -i error
```

## Resolution
Created a supplementary ClusterRole and ClusterRoleBinding persisted in Git and managed by ArgoCD:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: aws-load-balancer-controller-gateway
rules:
- apiGroups:
  - gateway.networking.k8s.io
  resources:
  - listenersets
  verbs:
  - get
  - list
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: aws-load-balancer-controller-gateway
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: aws-load-balancer-controller-gateway
subjects:
- kind: ServiceAccount
  name: aws-load-balancer-controller
  namespace: kube-system
```

## Lessons Learned
- When enabling new feature gates, always review what additional RBAC permissions may be required
- Supplementary RBAC should be version-controlled in Git, not applied manually
- Feature gates in Helm charts may not automatically update ClusterRoles

## Action Items
- [ ] File issue upstream to LBC repo requesting RBAC update in the default Helm chart
- [ ] Document required RBAC for Gateway API feature gate in project README
