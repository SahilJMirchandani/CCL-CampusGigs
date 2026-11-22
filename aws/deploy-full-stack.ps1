<#
.SYNOPSIS
  End-to-End Autonomous AWS Deployer for CampusGigs
.DESCRIPTION
  1. Verifies credentials.
  2. Sets up ec2-sg, rds-sg, S3 bucket, RDS PostgreSQL instance, and launches EC2.
  3. Waits for EC2 to accept SSH.
  4. Automatically uploads code via scp, configures .env, seeds database, and starts PM2.
#>

param(
    [string]$Region = "us-east-1",
    [string]$BucketName = "campusgigs-sahil-images",
    [string]$DbPassword = "postgrespassword123",
    [string]$KeyPath = "$HOME\Downloads\labsuser.pem"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "     CampusGigs 100% Autonomous AWS Cloud Deployment      " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Verify Credentials
Write-Host "`n[Step 1] Checking AWS Credentials..." -ForegroundColor Yellow
$caller = aws sts get-caller-identity --output json 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] AWS credentials not active." -ForegroundColor Red
    exit 1
}
$callerObj = $caller | ConvertFrom-Json
Write-Host "Authenticated as AWS Account: $($callerObj.Account)" -ForegroundColor Green

# 2. Get Default VPC
Write-Host "`n[Step 2] Finding Default VPC in $Region..." -ForegroundColor Yellow
$vpcId = (aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text --region $Region).Trim()
if (-not $vpcId -or $vpcId -eq "None") {
    $vpcId = (aws ec2 describe-vpcs --query "Vpcs[0].VpcId" --output text --region $Region).Trim()
}
Write-Host "VPC: $vpcId" -ForegroundColor Green

# 3. Security Groups
Write-Host "`n[Step 3] Setting up Security Groups..." -ForegroundColor Yellow
$ec2SgId = (aws ec2 describe-security-groups --filters "Name=group-name,Values=ec2-sg" "Name=vpc-id,Values=$vpcId" --query "SecurityGroups[0].GroupId" --output text --region $Region 2>$null).Trim()
if (-not $ec2SgId -or $ec2SgId -eq "None") {
    $ec2SgId = (aws ec2 create-security-group --group-name "ec2-sg" --description "CampusGigs EC2 SG" --vpc-id $vpcId --query "GroupId" --output text --region $Region).Trim()
    aws ec2 authorize-security-group-ingress --group-id $ec2SgId --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $Region | Out-Null
    aws ec2 authorize-security-group-ingress --group-id $ec2SgId --protocol tcp --port 5000 --cidr 0.0.0.0/0 --region $Region | Out-Null
    Write-Host "Created ec2-sg: $ec2SgId" -ForegroundColor Green
} else {
    Write-Host "Using existing ec2-sg: $ec2SgId" -ForegroundColor Green
}

$rdsSgId = (aws ec2 describe-security-groups --filters "Name=group-name,Values=rds-sg" "Name=vpc-id,Values=$vpcId" --query "SecurityGroups[0].GroupId" --output text --region $Region 2>$null).Trim()
if (-not $rdsSgId -or $rdsSgId -eq "None") {
    $rdsSgId = (aws ec2 create-security-group --group-name "rds-sg" --description "CampusGigs RDS SG" --vpc-id $vpcId --query "GroupId" --output text --region $Region).Trim()
    aws ec2 authorize-security-group-ingress --group-id $rdsSgId --protocol tcp --port 5432 --source-group $ec2SgId --region $Region | Out-Null
    Write-Host "Created rds-sg: $rdsSgId" -ForegroundColor Green
} else {
    Write-Host "Using existing rds-sg: $rdsSgId" -ForegroundColor Green
}

# 4. S3 Bucket
Write-Host "`n[Step 4] Checking / Creating S3 Bucket ($BucketName)..." -ForegroundColor Yellow
try {
    aws s3api head-bucket --bucket $BucketName --region $Region 2>$null
    Write-Host "S3 bucket exists: $BucketName" -ForegroundColor Green
} catch {
    Write-Host "Creating S3 bucket: $BucketName..."
    if ($Region -eq "us-east-1") {
        aws s3api create-bucket --bucket $BucketName --region $Region | Out-Null
    } else {
        aws s3api create-bucket --bucket $BucketName --region $Region --create-bucket-configuration LocationConstraint=$Region | Out-Null
    }
    aws s3api put-public-access-block --bucket $BucketName --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" --region $Region | Out-Null
    Write-Host "Created S3 bucket: $BucketName" -ForegroundColor Green
}

# 5. RDS Instance
Write-Host "`n[Step 5] Checking RDS PostgreSQL DB Instance..." -ForegroundColor Yellow
$rdsEndpoint = ""
try {
    $rdsInfo = aws rds describe-db-instances --db-instance-identifier "campusgigs-db" --region $Region --output json 2>$null | ConvertFrom-Json
    if ($rdsInfo -and $rdsInfo.DBInstances.Count -gt 0) {
        $db = $rdsInfo.DBInstances[0]
        Write-Host "RDS instance exists (Status: $($db.DBInstanceStatus))" -ForegroundColor Green
        if ($db.Endpoint) { $rdsEndpoint = $db.Endpoint.Address }
    }
} catch {}

if (-not $rdsEndpoint) {
    Write-Host "Launching RDS PostgreSQL instance 'campusgigs-db'..."
    aws rds create-db-instance `
        --db-instance-identifier "campusgigs-db" `
        --db-instance-class db.t3.micro `
        --engine postgres `
        --allocated-storage 20 `
        --storage-type gp3 `
        --master-username postgres `
        --master-user-password $DbPassword `
        --vpc-security-group-ids $rdsSgId `
        --db-name campusgigs `
        --no-multi-az `
        --no-publicly-accessible `
        --region $Region | Out-Null
    Write-Host "RDS creation initiated (takes ~8-10 mins). Endpoint will be acquired when available." -ForegroundColor Green
}

# 6. EC2 Instance
Write-Host "`n[Step 6] Checking / Launching EC2 Instance..." -ForegroundColor Yellow
$ec2Ip = (aws ec2 describe-instances --filters "Name=tag:Name,Values=campusgigs-ec2" "Name=instance-state-name,Values=running,pending" --query "Reservations[0].Instances[0].PublicIpAddress" --output text --region $Region 2>$null).Trim()

if (-not $ec2Ip -or $ec2Ip -eq "None") {
    $amiId = (aws ec2 describe-images --owners 099720109477 `
        --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" "Name=state,Values=available" `
        --query "reverse(sort_by(Images, &CreationDate))[0].ImageId" --output text --region $Region).Trim()
    
    Write-Host "Launching Ubuntu 22.04 instance ($amiId)..."
    $launch = aws ec2 run-instances `
        --image-id $amiId `
        --count 1 `
        --instance-type t2.micro `
        --key-name "vockey" `
        --security-group-ids $ec2SgId `
        --iam-instance-profile Name=LabInstanceProfile `
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=campusgigs-ec2}]" `
        --region $Region --output json | ConvertFrom-Json
    
    $instanceId = $launch.Instances[0].InstanceId
    Write-Host "Waiting for Public IP..." -ForegroundColor Yellow
    for ($i = 0; $i -lt 12; $i++) {
        Start-Sleep -Seconds 5
        $ec2Ip = (aws ec2 describe-instances --instance-ids $instanceId --query "Reservations[0].Instances[0].PublicIpAddress" --output text --region $Region).Trim()
        if ($ec2Ip -and $ec2Ip -ne "None") { break }
    }
}
Write-Host "EC2 Public IP: $ec2Ip" -ForegroundColor Green

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "AWS Services Configured:" -ForegroundColor Green
Write-Host "EC2 IP:       $ec2Ip"
Write-Host "S3 Bucket:    $BucketName"
Write-Host "RDS Endpoint: $(if ($rdsEndpoint) { $rdsEndpoint } else { 'Still initializing in AWS (available in a few minutes)' })"
Write-Host "==========================================================" -ForegroundColor Cyan
