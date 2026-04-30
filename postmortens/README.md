# Link Vault — Postmortems

A collection of postmortems documenting real incidents encountered during the setup of the Link Vault platform on AWS EKS. Each document follows a standard format: Summary, Timeline, Root Cause, Impact, Detection, Resolution, and Lessons Learned.

---

## Index

| # | Title | Severity | Component |
|---|-------|----------|-----------|
| 01 | [GatewayClass Wrong controllerName](01-gatewayclass-wrong-controller-name.md) | High | Gateway API |
| 02 | [LBC Missing RBAC for ListenerSets](02-lbc-missing-rbac-listenersets.md) | High | LBC / RBAC |
| 03 | [LBC CrashLoopBackOff — Missing Gateway CRDs](03-lbc-crashloop-missing-gateway-crds.md) | Critical | LBC / CRDs |
| 04 | [ALB Stuck in Unknown — Missing LB Config CRDs](04-alb-stuck-unknown-missing-lb-config.md) | High | Gateway API / ALB |
| 05 | [Karpenter Node Not Registering — Missing aws-auth Entry](05-karpenter-node-not-registering-aws-auth.md) | High | Karpenter / IAM |
| 06 | [Karpenter CreateFleet — Missing fleet/* IAM Resource](06-karpenter-createfleet-missing-fleet-resource.md) | High | Karpenter / IAM |
| 07 | [ESO AccessDeniedException — RDS Managed Secret ARN](07-eso-access-denied-rds-secret-arn.md) | High | ESO / IAM |
| 08 | [kube-prometheus-stack Tolerations Key Mismatch](08-kube-prometheus-tolerations-key-mismatch.md) | Medium | Monitoring |
| 09 | [ArgoCD App Stuck Deleting — Finalizer Blocking](09-argocd-app-stuck-deleting-finalizer.md) | Medium | ArgoCD |
| 10 | [Backend CrashLoopBackOff — Missing asyncpg Driver](10-backend-crashloop-missing-asyncpg-driver.md) | High | Application |

---

## Common Themes

**IAM & Permissions (3 incidents)**
Incidents 05, 06, 07 — Always verify IAM policies cover both actions AND resource ARNs. RDS managed secrets use `rds!` prefix which won't match path-based wildcards.

**Missing CRDs (2 incidents)**
Incidents 03, 04 — LBC v3.2.0 with Gateway API requires both standard and experimental CRD channels, plus additional LBC-specific CRDs.

**Configuration Mismatches (3 incidents)**
Incidents 01, 08, 10 — Field names, driver specifiers, and controller identities must be verified against the actual version being used, not documentation.

**GitOps Operations (2 incidents)**
Incidents 02, 09 — RBAC and hook resources should be managed via Git. Manual changes during debugging can leave systems in inconsistent states.
