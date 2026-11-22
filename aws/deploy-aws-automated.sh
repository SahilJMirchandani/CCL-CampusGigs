#!/bin/bash
# ==============================================================================
# CampusGigs AWS Automated Provisioner (Bash / AWS CLI)
# ==============================================================================
set -e

REGION="${AWS_REGION:-us-east-1}"
BUCKET_NAME="${S3_BUCKET:-campusgigs-sahil-images}"
DB_PASSWORD="${DB_PASSWORD:-postgrespassword123}"
KEY_NAME="${KEY_NAME:-vockey}"
DB_IDENTIFIER="${DB_IDENTIFIER:-campusgigs-db}"

echo "=========================================================="
echo "   CampusGigs AWS Automated Provisioner (CCL Project)     "
echo "=========================================================="

echo -e "\n[1/6] Verifying AWS Credentials..."
if ! aws sts get-caller-identity --region "$REGION" > /dev/null 2>&1; then
    echo "[ERROR] AWS credentials not found or expired."
    echo "If using AWS Academy Learner Lab:"
    echo "1. Click 'Start Lab' in Learner Lab."
    echo "2. Click 'AWS Details' (next to the green AWS button)."
    echo "3. Copy the AWS CLI snippet into ~/.aws/credentials"
    exit 1
fi
echo "AWS credentials verified."

echo -e "\n[2/6] Detecting Default VPC in $REGION..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text --region "$REGION")
if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
    VPC_ID=$(aws ec2 describe-vpcs --query "Vpcs[0].VpcId" --output text --region "$REGION")
fi
echo "Using VPC: $VPC_ID"

echo -e "\n[3/6] Setting up Security Groups (ec2-sg and rds-sg)..."
EC2_SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=ec2-sg" "Name=vpc-id,Values=$VPC_ID" --query "SecurityGroups[0].GroupId" --output text --region "$REGION" 2>/dev/null || true)
if [ -z "$EC2_SG_ID" ] || [ "$EC2_SG_ID" == "None" ]; then
    echo "Creating ec2-sg..."
    EC2_SG_ID=$(aws ec2 create-security-group --group-name "ec2-sg" --description "CampusGigs EC2 Security Group" --vpc-id "$VPC_ID" --query "GroupId" --output text --region "$REGION")
    aws ec2 authorize-security-group-ingress --group-id "$EC2_SG_ID" --protocol tcp --port 22 --cidr 0.0.0.0/0 --region "$REGION"
    aws ec2 authorize-security-group-ingress --group-id "$EC2_SG_ID" --protocol tcp --port 5000 --cidr 0.0.0.0/0 --region "$REGION"
    echo "Created ec2-sg: $EC2_SG_ID"
else
    echo "Existing ec2-sg: $EC2_SG_ID"
fi

RDS_SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=rds-sg" "Name=vpc-id,Values=$VPC_ID" --query "SecurityGroups[0].GroupId" --output text --region "$REGION" 2>/dev/null || true)
if [ -z "$RDS_SG_ID" ] || [ "$RDS_SG_ID" == "None" ]; then
    echo "Creating rds-sg..."
    RDS_SG_ID=$(aws ec2 create-security-group --group-name "rds-sg" --description "CampusGigs RDS PostgreSQL Security Group" --vpc-id "$VPC_ID" --query "GroupId" --output text --region "$REGION")
    aws ec2 authorize-security-group-ingress --group-id "$RDS_SG_ID" --protocol tcp --port 5432 --source-group "$EC2_SG_ID" --region "$REGION"
    echo "Created rds-sg: $RDS_SG_ID"
else
    echo "Existing rds-sg: $RDS_SG_ID"
fi

echo -e "\n[4/6] Setting up S3 Bucket ($BUCKET_NAME)..."
if ! aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "Creating S3 bucket: $BUCKET_NAME..."
    if [ "$REGION" == "us-east-1" ]; then
        aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION"
    else
        aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" --create-bucket-configuration LocationConstraint="$REGION"
    fi
    aws s3api put-public-access-block --bucket "$BUCKET_NAME" --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" --region "$REGION"
    echo "Created S3 bucket: $BUCKET_NAME"
else
    echo "S3 bucket already exists: $BUCKET_NAME"
fi

echo -e "\n[5/6] Checking RDS PostgreSQL DB Instance..."
RDS_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier "$DB_IDENTIFIER" --query "DBInstances[0].Endpoint.Address" --output text --region "$REGION" 2>/dev/null || true)
if [ -z "$RDS_ENDPOINT" ] || [ "$RDS_ENDPOINT" == "None" ]; then
    echo "Creating RDS PostgreSQL DB instance ($DB_IDENTIFIER)..."
    aws rds create-db-instance \
        --db-instance-identifier "$DB_IDENTIFIER" \
        --db-instance-class db.t3.micro \
        --engine postgres \
        --allocated-storage 20 \
        --storage-type gp3 \
        --master-username postgres \
        --master-user-password "$DB_PASSWORD" \
        --vpc-security-group-ids "$RDS_SG_ID" \
        --db-name campusgigs \
        --no-multi-az \
        --no-publicly-accessible \
        --region "$REGION"
    echo "RDS creation initiated (takes ~8-10 min)."
else
    echo "RDS Endpoint: $RDS_ENDPOINT"
fi

echo -e "\n[6/6] Checking / Launching EC2 Instance..."
EC2_IP=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=campusgigs-ec2" "Name=instance-state-name,Values=running,pending" --query "Reservations[0].Instances[0].PublicIpAddress" --output text --region "$REGION" 2>/dev/null || true)
if [ -z "$EC2_IP" ] || [ "$EC2_IP" == "None" ]; then
    AMI_ID=$(aws ec2 describe-images --owners 099720109477 \
        --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" "Name=state,Values=available" \
        --query "reverse(sort_by(Images, &CreationDate))[0].ImageId" --output text --region "$REGION")
    echo "Launching EC2 instance using AMI $AMI_ID..."
    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id "$AMI_ID" \
        --count 1 \
        --instance-type t2.micro \
        --key-name "$KEY_NAME" \
        --security-group-ids "$EC2_SG_ID" \
        --iam-instance-profile Name=LabInstanceProfile \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=campusgigs-ec2}]" \
        --query "Instances[0].InstanceId" --output text --region "$REGION")
    echo "Instance launched: $INSTANCE_ID. Waiting for IP..."
    sleep 10
    EC2_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query "Reservations[0].Instances[0].PublicIpAddress" --output text --region "$REGION")
fi
echo "EC2 Public IP: $EC2_IP"

echo "=========================================================="
echo "Setup initiated. Once RDS is Available, deploy using:"
echo "ssh -i labsuser.pem ubuntu@$EC2_IP"
echo "=========================================================="
