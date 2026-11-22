#!/usr/bin/env bash
# CampusGigs - Amazon S3 Media Upload Utility for EC2 and Linux
set -euo pipefail

BUCKET_NAME="${S3_BUCKET:-campusgigs-sahil-779634-images}"
REGION="${AWS_REGION:-us-east-1}"

echo "========================================================"
echo "  Uploading CampusGigs Media to Amazon S3"
echo "  Bucket: s3://${BUCKET_NAME}"
echo "  Region: ${REGION}"
echo "========================================================"

UPLOADS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../server/uploads" && pwd)"

if command -v aws >/dev/null 2>&1; then
  echo "[INFO] Using AWS CLI with IAM LabRole on EC2..."
  aws s3 sync "${UPLOADS_DIR}/" "s3://${BUCKET_NAME}/" --region "${REGION}"
  echo "[SUCCESS] Media successfully synced to s3://${BUCKET_NAME}/"
else
  echo "[INFO] Running Node.js synchronizer..."
  node "$(dirname "${BASH_SOURCE[0]}")/../server/src/services/populate-s3-media.js"
fi
