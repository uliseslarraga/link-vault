# Link Vault — Architecture

## Overview

Link Vault is a containerized monorepo app for saving URLs with notes.
It demonstrates a production-like stack with a React frontend, FastAPI backend,
PostgreSQL database, and S3-compatible object storage.

## Components

```
┌─────────────────────────────────────────────────────────┐
│                        Browser                          │
└───────────────────────┬─────────────────────────────────┘
                        │ HTTP :3000
┌───────────────────────▼─────────────────────────────────┐
│              Frontend (React + Nginx)                   │
│  - Static SPA served by Nginx                           │
│  - Proxies /api/* to backend                            │
└───────────────────────┬─────────────────────────────────┘
                        │ HTTP :8000
┌───────────────────────▼─────────────────────────────────┐
│              Backend (FastAPI + asyncpg)                │
│  - REST API: CRUD for links                             │
│  - Generates presigned S3 URLs per request              │
│  - Runs DB migrations on startup via SQLAlchemy         │
└────────────┬──────────────────────────┬─────────────────┘
             │ SQL (asyncpg)            │ AWS SDK (boto3)
┌────────────▼────────┐    ┌────────────▼─────────────────┐
│  PostgreSQL :5432   │    │  LocalStack S3 :4566         │
│  - links table      │    │  - link-vault bucket         │
│  - Persisted volume │    │  - Screenshot objects        │
└─────────────────────┘    └──────────────────────────────┘
```

## Key Design Decisions

### Presigned URLs (not public S3)
Screenshots are never exposed via public S3 URLs. The backend generates
a presigned GET URL per request, valid for 1 hour. This means:
- S3 bucket stays private
- URLs expire automatically
- No extra auth layer needed on the CDN side

### Async all the way
FastAPI + asyncpg + SQLAlchemy async means the backend never blocks
on I/O. Under load, this matters for DB-heavy endpoints.

### Non-root containers
Both Dockerfiles run the app as a non-root user. This is a basic
security practice that reduces blast radius if a container is compromised.

### Health checks with depends_on conditions
`docker-compose` waits for postgres and localstack to be *healthy*
(not just started) before launching the backend. This avoids race
conditions during `make up`.

### LocalStack → AWS parity
The backend uses `S3_ENDPOINT_URL` to point boto3 at LocalStack in dev.
In production, removing that env var makes boto3 use real AWS automatically.
Zero code changes needed.

## Environment Progression

| Stage      | DB           | S3           | Secrets         |
|------------|--------------|--------------|-----------------|
| Local dev  | Docker PG    | LocalStack   | .env file       |
| CI         | Docker PG    | LocalStack   | GitHub Secrets  |
| Production | RDS          | S3           | AWS Secrets Mgr |
