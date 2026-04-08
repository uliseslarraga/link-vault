import os
import boto3
from botocore.exceptions import ClientError
from botocore.config import Config

S3_BUCKET = os.getenv("S3_BUCKET", "link-vault")
AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
S3_ENDPOINT_URL = os.getenv("S3_ENDPOINT_URL", None)  # For LocalStack
PRESIGNED_URL_EXPIRY = int(os.getenv("PRESIGNED_URL_EXPIRY", "3600"))


def get_s3_client():
    kwargs = {
        "region_name": AWS_REGION,
        "config": Config(signature_version="s3v4"),
    }
    # LocalStack / MinIO support
    if S3_ENDPOINT_URL:
        kwargs["endpoint_url"] = S3_ENDPOINT_URL
        kwargs["aws_access_key_id"] = os.getenv("AWS_ACCESS_KEY_ID", "test")
        kwargs["aws_secret_access_key"] = os.getenv("AWS_SECRET_ACCESS_KEY", "test")

    return boto3.client("s3", **kwargs)


def ensure_bucket_exists():
    client = get_s3_client()
    try:
        client.head_bucket(Bucket=S3_BUCKET)
    except ClientError as e:
        if e.response["Error"]["Code"] == "404":
            client.create_bucket(Bucket=S3_BUCKET)


def upload_screenshot(key: str, data: bytes, content_type: str = "image/png") -> str:
    """Upload screenshot bytes to S3, return the object key."""
    client = get_s3_client()
    ensure_bucket_exists()
    client.put_object(
        Bucket=S3_BUCKET,
        Key=key,
        Body=data,
        ContentType=content_type,
    )
    return key


def get_presigned_url(key: str) -> str | None:
    """Generate a presigned GET URL valid for PRESIGNED_URL_EXPIRY seconds."""
    if not key:
        return None
    client = get_s3_client()
    try:
        url = client.generate_presigned_url(
            "get_object",
            Params={"Bucket": S3_BUCKET, "Key": key},
            ExpiresIn=PRESIGNED_URL_EXPIRY,
        )
        return url
    except ClientError:
        return None


def delete_screenshot(key: str) -> None:
    client = get_s3_client()
    try:
        client.delete_object(Bucket=S3_BUCKET, Key=key)
    except ClientError:
        pass
