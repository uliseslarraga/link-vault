#!/bin/bash
# Runs automatically when LocalStack is ready.
# Creates the S3 bucket for local development.

BUCKET="${S3_BUCKET:-link-vault}"
REGION="us-east-1"

echo "[init] Creating S3 bucket: $BUCKET"

awslocal s3api create-bucket \
  --bucket "$BUCKET" \
  --region "$REGION"

awslocal s3api put-bucket-cors \
  --bucket "$BUCKET" \
  --cors-configuration '{
    "CORSRules": [{
      "AllowedOrigins": ["*"],
      "AllowedMethods": ["GET", "PUT", "POST", "DELETE"],
      "AllowedHeaders": ["*"],
      "MaxAgeSeconds": 3000
    }]
  }'

echo "[init] Bucket $BUCKET ready."
