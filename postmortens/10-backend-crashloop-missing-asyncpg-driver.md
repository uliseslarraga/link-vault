# Postmortem: Backend CrashLoopBackOff — Missing asyncpg Driver in DATABASE_URL

## Summary
The backend application failed to start after database credentials were successfully synced via External Secrets Operator. The `DATABASE_URL` was constructed without the `+asyncpg` driver specifier required by SQLAlchemy's async engine.

## Date
April 2026

## Severity
High — Backend completely unavailable despite infrastructure being correctly configured.

## Timeline
| Time | Event |
|------|-------|
| T+0  | ExternalSecret synced successfully, `link-vault-backend-secret` created |
| T+5m | Backend pods restarted, entered CrashLoopBackOff |
| T+10m | Checked pod logs, found SQLAlchemy engine error |
| T+15m | Identified missing `+asyncpg` in DATABASE_URL |
| T+20m | Updated ExternalSecret template in Git |
| T+25m | ArgoCD synced, ESO re-synced secret |
| T+30m | Backend pods running successfully |

## Root Cause
The `DATABASE_URL` was constructed in the ExternalSecret template as:
```
postgresql://username:password@host:5432/dbname
```

The backend uses SQLAlchemy's `create_async_engine` which requires an async-compatible database driver. For PostgreSQL, this is `asyncpg`. Without specifying the driver in the URL scheme, SQLAlchemy attempted to import `psycopg2` (the default sync driver), which was not installed in the container.

Error observed:
```python
File "/app/db/session.py", line 10, in <module>
    engine = create_async_engine(DATABASE_URL, echo=False)
ModuleNotFoundError: No module named 'psycopg2'
```

## Impact
- Backend pods in CrashLoopBackOff
- Application completely unavailable
- Frontend unable to reach backend API

## Detection
```bash
kubectl logs -n backend deployment/link-vault-backend
```

## Resolution
Updated the ExternalSecret template to include the `+asyncpg` driver specifier:

```yaml
# Before
DATABASE_URL: "postgresql://{{ .username }}:{{ .password }}@host:5432/dbname"

# After
DATABASE_URL: "postgresql+asyncpg://{{ .username }}:{{ .password }}@host:5432/dbname"
```

The full ExternalSecret template:
```yaml
target:
  name: link-vault-backend-secret
  creationPolicy: Owner
  template:
    data:
      DATABASE_URL: "postgresql+asyncpg://{{ .username }}:{{ .password }}@link-vault-dev-postgres.cuxc0m8yeddg.us-east-1.rds.amazonaws.com:5432/linkvault"
      DB_USERNAME: "{{ .username }}"
      DB_PASSWORD: "{{ .password }}"
```

## Lessons Learned
- SQLAlchemy async engine requires the driver to be specified explicitly in the URL scheme
- `postgresql://` → sync (psycopg2)
- `postgresql+asyncpg://` → async (asyncpg)
- Secret templates should be validated against application requirements before deployment

## Action Items
- [ ] Add DATABASE_URL format to backend documentation
- [ ] Add application startup smoke test to CI pipeline to catch driver issues before reaching production
- [ ] Consider adding a readiness probe that verifies database connectivity on startup
