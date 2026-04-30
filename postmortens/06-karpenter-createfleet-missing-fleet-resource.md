# Postmortem: Karpenter CreateFleet — Missing fleet/* IAM Resource

## Summary
Karpenter's EC2NodeClass showed `ValidationSucceeded=False` with an authorization error for `ec2:CreateFleet`. Despite the IAM policy containing the `ec2:CreateFleet` action, the policy's resource scope did not include `fleet/*`, causing all fleet creation attempts to fail.

## Date
April 2026

## Severity
High — Karpenter could not provision any nodes.

## Timeline
| Time | Event |
|------|-------|
| T+0  | Karpenter deployed, NodePool and EC2NodeClass created |
| T+10m | EC2NodeClass status: `ValidationSucceeded=False` |
| T+15m | Error: `Controller isn't authorized to call ec2:CreateFleet` |
| T+20m | Verified IAM policy contains `ec2:CreateFleet` action |
| T+30m | Identified missing `fleet/*` resource in policy |
| T+40m | Updated Terraform IAM policy, applied |
| T+50m | EC2NodeClass status: `Ready=True` |

## Root Cause
The IAM policy for the Karpenter controller role included `ec2:CreateFleet` in the `Action` list, but the `Resource` block for that statement did not include `arn:aws:ec2:*:*:fleet/*`. AWS IAM evaluates both the action AND the resource — having the action without the matching resource ARN results in an implicit deny.

**Before (missing fleet resource):**
```json
{
  "Action": ["ec2:RunInstances", "ec2:CreateFleet"],
  "Effect": "Allow",
  "Resource": [
    "arn:aws:ec2:us-east-1:*:instance/*",
    "arn:aws:ec2:us-east-1:*:subnet/*",
    "arn:aws:ec2:us-east-1:*:security-group/*"
  ]
}
```

**After (fleet resource added):**
```json
{
  "Action": ["ec2:RunInstances", "ec2:CreateFleet"],
  "Effect": "Allow",
  "Resource": [
    "arn:aws:ec2:us-east-1:*:instance/*",
    "arn:aws:ec2:us-east-1:*:subnet/*",
    "arn:aws:ec2:us-east-1:*:security-group/*",
    "arn:aws:ec2:us-east-1:*:fleet/*"
  ]
}
```

## Impact
- Karpenter unable to provision any EC2 instances
- All pending pods remained unscheduled
- EC2NodeClass in degraded state

## Detection
```bash
kubectl describe ec2nodeclass default
```

Status conditions showed:
```
Message: Controller isn't authorized to call ec2:CreateFleet
Reason:  CreateFleetAuthCheckFailed
```

## Resolution
Updated the Terraform IAM policy to include `fleet/*` resource:

```hcl
resources = [
  "arn:aws:ec2:${var.region}:*:instance/*",
  "arn:aws:ec2:${var.region}:*:subnet/*",
  "arn:aws:ec2:${var.region}:*:security-group/*",
  "arn:aws:ec2:${var.region}:*:launch-template/*",
  "arn:aws:ec2:${var.region}:*:fleet/*",  # Added
  "arn:aws:ec2:${var.region}::snapshot/*",
  "arn:aws:ec2:${var.region}::image/*",
]
```

## Lessons Learned
- IAM policies require both the correct Action AND the correct Resource ARN
- `ec2:CreateFleet` operates on `fleet/*` resources which must be explicitly allowed
- Always use the official Karpenter IAM policy from the repo as a reference

## Action Items
- [ ] Compare current IAM policy with official Karpenter policy after each upgrade
- [ ] Add IAM policy validation to CI pipeline
