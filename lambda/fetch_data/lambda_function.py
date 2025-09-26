import os
import json
import urllib.request
import boto3
from datetime import datetime, timezone

s3 = boto3.client("s3")
BUCKET = os.environ.get("BUCKET_NAME")
URL = os.environ.get("DATA_URL")

def lambda_handler(event, context):
    if not BUCKET or not URL:
        raise RuntimeError("Missing BUCKET_NAME or DATA_URL environment variables")

    # Fetch remote data
    req = urllib.request.Request(URL, headers={"User-Agent": "epi-mvp/1.0"})
    with urllib.request.urlopen(req, timeout=20) as resp:
        body = resp.read()

    # Store into S3 under date-based prefix
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    key = f"{today}/data.json"

    s3.put_object(
        Bucket=BUCKET,
        Key=key,
        Body=body,
        ContentType="application/json"
    )

    return {"status": "ok", "bucket": BUCKET, "key": key, "bytes": len(body)}
