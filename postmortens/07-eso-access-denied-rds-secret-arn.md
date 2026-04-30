# Postmortem: ESO AccessDeniedException — RDS Managed Secret ARN Not Matching IAM Policy

## Summary
The External Secrets Operator failed to sync the RDS database credentials from AWS Secrets Manager. The IAM policy used a wildcard pattern `link-vault/*` that did not match the RDS managed secret ARN which starts with `rds!`.

## Date
April 2026

## Severity
High — Backend pods could not start without the database credentials secret.

## Timeline
| Time | Event |
|------|-------|
| T+0  | ExternalSecret created pointing to RDS managed secret |
| T+5m | ESO reported `SecretSyncedError` |
| T+10m | Found `AccessDeniedException` in ESO logs |
| T+20m | Identified ARN mismatch between policy and secret |
| T+30m | Updated Terraform IAM policy with explicit ARN |
| T+40m | Applied Terraform changes |
| T+50m | ESO synced successfully, secret created |

## Root Cause
AWS RDS managed secrets have a special ARN format starting with `rds!` instead of a user-defined path:

```
# User-defined secret (matches link-vault/* wildcard)
arn:aws:secretsmanager:us-east-1:289296207513:secret:link-vault/db-password

# RDS managed secret (does NOT match link-vault/* wildcard)
arn:aws:secretsmanager:us-east-1:289296207513:secret:rds!db-685efd46-54aa-41ea-bbaa-2e625b15dca0-AMpHWT
```

The ESO IAM policy only allowed access to `link-vault/*` resources, so the `rds!` prefixed secret was denied.

Error observed:
```json
{
  "error": "operation error Secrets Manager: GetSecretValue, 
  AccessDeniedException: User arn:aws:sts::289296207513:assumed-role/link-vault-dev-eso/
  external-secrets-provider-aws is not authorized to perform: 
  secretsmanager:GetSecretValue on resource: 
  rds!db-685efd46-54aa-41ea-bbaa-2e625b15dca0"
}
```

## Impact
- Database credentials not synced to Kubernetes
- Backend pods in `CrashLoopBackOff` — missing secret
- Application completely unavailable

## Detection
```bash
kubectl logs -n external-secrets deployment/external-secrets | grep error
kubectl get externalsecret -n backend
```

## Resolution
Added the explicit RDS managed secret ARN to the ESO IAM policy in Terraform:

```hcl
resources = [
  "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:link-vault/*",
  "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:rds!db-685efd46-54aa-41ea-bbaa-2e625b15dca0-AMpHWT",
]
```

## Lessons Learned
- RDS managed secrets use the `rds!` prefix — wildcard patterns based on path will not match
- When using RDS managed secrets, always add the explicit ARN to IAM policies
- Consider using a custom secret in Secrets Manager and rotating it via Lambda if you need path-based wildcard access

## Action Items
- [ ] Document RDS managed secret ARN format in project README
- [ ] Add explicit ARN output from RDS Terraform module to avoid manual lookup
- [ ] Consider migrating to custom secret with automated rotation for easier IAM management
