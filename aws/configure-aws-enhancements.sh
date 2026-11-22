#!/bin/bash
# ==============================================================================
# AWS Advanced Enhancements for CampusGigs (CCL Evaluation Showcase)
# Enables:
# 1. S3 Bucket Versioning & SSE-S3 Encryption
# 2. S3 Lifecycle Transition Rules (Cloud Cost Optimization)
# 3. Amazon CloudWatch Metric Alarms (EC2 CPU & RDS Connections)
# 4. Amazon RDS Manual Backup Snapshot (Disaster Recovery Demonstration)
# ==============================================================================
set -e

REGION="${AWS_REGION:-us-east-1}"
BUCKET_NAME="${S3_BUCKET:-campusgigs-sahil-779634-images}"
DB_IDENTIFIER="${DB_IDENTIFIER:-campusgigs-db}"

echo "=========================================================="
echo "    Configuring AWS Well-Architected Cloud Enhancements    "
echo "=========================================================="

# 1. Enable S3 Bucket Versioning
echo -e "\n[1/5] Enabling S3 Bucket Versioning..."
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled \
    --region "$REGION"
echo "S3 Versioning Enabled."

# 2. Enable S3 Server-Side Encryption (SSE-S3 / AES256)
echo -e "\n[2/5] Enabling Default Server-Side Encryption on S3..."
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }' \
    --region "$REGION"
echo "S3 Server-Side Encryption (AES256) Enabled."

# 3. S3 Lifecycle Rule (Cost Optimization: Transition to Standard-IA after 30 days)
echo -e "\n[3/5] Applying S3 Lifecycle Transition Policy..."
aws s3api put-bucket-lifecycle-configuration \
    --bucket "$BUCKET_NAME" \
    --lifecycle-configuration '{
        "Rules": [{
            "ID": "CostOptimizationPolicy",
            "Status": "Enabled",
            "Filter": { "Prefix": "" },
            "Transitions": [{
                "Days": 30,
                "StorageClass": "STANDARD_IA"
            }]
        }]
    }' \
    --region "$REGION"
echo "S3 Lifecycle Policy configured."

# 4. Amazon CloudWatch Metric Alarms
echo -e "\n[4/5] Setting up Amazon CloudWatch Alarms..."
EC2_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=campusgigs-ec2" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].InstanceId" --output text --region "$REGION" 2>/dev/null || true)

if [ -n "$EC2_ID" ] && [ "$EC2_ID" != "None" ]; then
    echo "Creating CloudWatch Alarm for EC2 CPU Utilization..."
    aws cloudwatch put-metric-alarm \
        --alarm-name "CampusGigs-EC2-HighCPU" \
        --alarm-description "Triggers if EC2 CPU exceeds 80% for 5 minutes" \
        --metric-name CPUUtilization \
        --namespace AWS/EC2 \
        --statistic Average \
        --period 300 \
        --threshold 80 \
        --comparison-operator GreaterThanOrEqualToThreshold \
        --dimensions Name=InstanceId,Value="$EC2_ID" \
        --evaluation-periods 1 \
        --region "$REGION"
    echo "CloudWatch EC2 Alarm configured."
fi

echo "Creating CloudWatch Alarm for RDS Free Storage..."
aws cloudwatch put-metric-alarm \
    --alarm-name "CampusGigs-RDS-LowStorage" \
    --alarm-description "Triggers if RDS free storage is below 2 GB" \
    --metric-name FreeStorageSpace \
    --namespace AWS/RDS \
    --statistic Average \
    --period 300 \
    --threshold 2147483648 \
    --comparison-operator LessThanOrEqualToThreshold \
    --dimensions Name=DBInstanceIdentifier,Value="$DB_IDENTIFIER" \
    --evaluation-periods 1 \
    --region "$REGION"
echo "CloudWatch RDS Alarm configured."

# 5. Create Manual RDS Snapshot
echo -e "\n[5/5] Creating RDS Point-in-Time Backup Snapshot..."
SNAPSHOT_ID="campusgigs-backup-$(date +%s)"
aws rds create-db-snapshot \
    --db-instance-identifier "$DB_IDENTIFIER" \
    --db-snapshot-identifier "$SNAPSHOT_ID" \
    --region "$REGION"
echo "RDS Backup Snapshot initiated: $SNAPSHOT_ID"

echo -e "\n=========================================================="
echo "    All AWS Well-Architected Enhancements Active!         "
echo "=========================================================="
