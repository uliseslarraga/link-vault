# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Install dependencies
pip install -r requirements.txt -r requirements-dev.txt

# Run the dev server
uvicorn main:app --reload

# Run all tests
pytest

# Run a single test
pytest tests/test_schemas.py::TestLinkCreate::test_valid_url

# Run tests with coverage
pytest --cov
```

## Architecture

FastAPI backend for saving and managing URLs with notes and auto-captured screenshots.

**Request flow for `POST /api/v1/links`:**
1. Link row is inserted into PostgreSQL immediately.
2. A FastAPI `BackgroundTask` calls `_capture_and_save_screenshot` — Playwright captures a PNG, uploads it to S3, then updates `links.screenshot_key` in a separate DB session.
3. The response is returned before the screenshot is ready; `screenshot_url` will be `null` initially.

**Two-client S3 split** (`services/s3.py`): internal operations (upload, delete) use `S3_ENDPOINT_URL`; presigned URL generation uses `S3_PRESIGN_ENDPOINT_URL`. In dev both point to LocalStack (`http://localhost:4566`), but they must be different env vars because the presigned URL must be resolvable by the browser, not the container.

**`screenshot_url` is never persisted.** `Link.screenshot_url` is a DB column but it's always `null` in storage. On every read, `_enrich_with_presigned()` generates a fresh presigned URL from `link.screenshot_key` and attaches it to the response.

**DB tables** are created on startup via the `lifespan` async context manager in `main.py` — no migration tooling is used.

## Environment Variables

| Variable | Default | Notes |
|---|---|---|
| `DATABASE_URL` | `postgresql+asyncpg://postgres:postgres@localhost:5432/linkvault` | |
| `S3_BUCKET` | `link-vault` | |
| `AWS_REGION` | `us-east-1` | |
| `S3_ENDPOINT_URL` | `None` (real AWS) | Set to `http://localstack:4566` for dev |
| `S3_PRESIGN_ENDPOINT_URL` | falls back to `S3_ENDPOINT_URL` | Must be browser-reachable; set to `http://localhost:4566` in dev |
| `PRESIGNED_URL_EXPIRY` | `3600` | Seconds |

LocalStack dev credentials default to `AWS_ACCESS_KEY_ID=test` / `AWS_SECRET_ACCESS_KEY=test`.
