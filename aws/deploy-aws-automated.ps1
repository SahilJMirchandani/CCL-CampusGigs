<#
.SYNOPSIS
  Automated AWS Infrastructure Provisioning for CampusGigs (Learner Lab / Standard AWS)
.DESCRIPTION
  Creates EC2 Security Group, RDS Security Group, S3 Bucket, RDS PostgreSQL instance, and launches EC2.
  Generates the production server/.env with endpoints prefilled.
#>

param(
    [string]$Region = "us-east-1",
    [string]$BucketName = "campusgigs-sahil-images",
    [string]$DbPassword = "postgrespassword123",
    [string]$KeyName = "vockey",
    [string]$DbInstanceIdentifier = "campusgigs-db",
    [switch]$SkipEC2 = $false
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   CampusGigs AWS Automated Provisioner (CCL Project)     " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Verify AWS CLI Credentials
Write-Host "`n[1/6] Verifying AWS Credentials..." -ForegroundColor Yellow
try {
    $identityJson = aws sts get-caller-identity --output json 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw $identityJson
    }
    $identity = $identityJson | ConvertFrom-Json
    Write-Host "Connected as AWS Account: $($identity.Account) (ARN: $($identity.Arn))" -ForegroundColor Green
} catch {
    Write-Host "`n[ERROR] Unable to connect to AWS. Credentials not found or expired." -ForegroundColor Red
    Write-Host "If using AWS Academy Learner Lab:" -ForegroundColor Yellow
    Write-Host "1. Click 'Start Lab' in Learner Lab."
    Write-Host "2. Click 'AWS Details' (next to the green AWS button)."
    Write-Host "3. Copy the AWS CLI snippet and paste it into ~/.aws/credentials"
    Write-Host "   or set AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN environment variables."
    exit 1
}

# 2. Get Default VPC
Write-Host "`n[2/6] Detecting Default VPC in $Region..." -ForegroundColor Yellow
$vpcId = (aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text --region $Region).Trim()
if (-not $vpcId -or $vpcId -eq "None") {
    $vpcId = (aws ec2 describe-vpcs --query "Vpcs[0].VpcId" --output text --region $Region).Trim()
}
Write-Host "Using VPC: $vpcId" -ForegroundColor Green

# 3. Create / Configure Security Groups
Write-Host "`n[3/6] Setting up Security Groups (ec2-sg and rds-sg)..." -ForegroundColor Yellow

# ec2-sg
$ec2SgId = (aws ec2 describe-security-groups --filters "Name=group-name,Values=ec2-sg" "Name=vpc-id,Values=$vpcId" --query "SecurityGroups[0].GroupId" --output text --region $Region).Trim()
if (-not $ec2SgId -or $ec2SgId -eq "None") {
    Write-Host "Creating ec2-sg..."
    $ec2SgId = (aws ec2 create-security-group --group-name "ec2-sg" --description "CampusGigs EC2 Security Group" --vpc-id $vpcId --query "GroupId" --output text --region $Region).Trim()
    aws ec2 authorize-security-group-ingress --group-id $ec2SgId --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $Region | Out-Null
    aws ec2 authorize-security-group-ingress --group-id $ec2SgId --protocol tcp --port 5000 --cidr 0.0.0.0/0 --region $Region | Out-Null
    Write-Host "Created ec2-sg: $ec2SgId (Ports 22 & 5000 open)" -ForegroundColor Green
} else {
    Write-Host "Existing ec2-sg found: $ec2SgId" -ForegroundColor Green
    # Ensure port 5000 is open
    try {
        aws ec2 authorize-security-group-ingress --group-id $ec2SgId --protocol tcp --port 5000 --cidr 0.0.0.0/0 --region $Region 2>$null | Out-Null
    } catch {}
}

# rds-sg
$rdsSgId = (aws ec2 describe-security-groups --filters "Name=group-name,Values=rds-sg" "Name=vpc-id,Values=$vpcId" --query "SecurityGroups[0].GroupId" --output text --region $Region).Trim()
if (-not $rdsSgId -or $rdsSgId -eq "None") {
    Write-Host "Creating rds-sg..."
    $rdsSgId = (aws ec2 create-security-group --group-name "rds-sg" --description "CampusGigs RDS PostgreSQL Security Group" --vpc-id $vpcId --query "GroupId" --output text --region $Region).Trim()
    aws ec2 authorize-security-group-ingress --group-id $rdsSgId --protocol tcp --port 5432 --source-group $ec2SgId --region $Region | Out-Null
    Write-Host "Created rds-sg: $rdsSgId (Port 5432 open from ec2-sg)" -ForegroundColor Green
} else {
    Write-Host "Existing rds-sg found: $rdsSgId" -ForegroundColor Green
}

# 4. S3 Bucket
Write-Host "`n[4/6] Setting up S3 Bucket ($BucketName)..." -ForegroundColor Yellow
$bucketExists = $false
try {
    aws s3api head-bucket --bucket $BucketName --region $Region 2>$null
    if ($LASTEXITCODE -eq 0) { $bucketExists = $true }
} catch {
    $bucketExists = $false
}

if (-not $bucketExists) {
    Write-Host "Creating S3 bucket: $BucketName..."
    if ($Region -eq "us-east-1") {
        aws s3api create-bucket --bucket $BucketName --region $Region | Out-Null
    } else {
        aws s3api create-bucket --bucket $BucketName --region $Region --create-bucket-configuration LocationConstraint=$Region | Out-Null
    }
    aws s3api put-public-access-block --bucket $BucketName --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" --region $Region | Out-Null
    Write-Host "Created S3 bucket: $BucketName (Private, Block Public Access ON)" -ForegroundColor Green
} else {
    Write-Host "S3 bucket already exists: $BucketName" -ForegroundColor Green
}

# 5. RDS PostgreSQL Instance
Write-Host "`n[5/6] Checking / Creating RDS PostgreSQL Instance ($DbInstanceIdentifier)..." -ForegroundColor Yellow
$rdsEndpoint = ""
try {
    $rdsInfo = aws rds describe-db-instances --db-instance-identifier $DbInstanceIdentifier --region $Region --output json 2>$null | ConvertFrom-Json
    if ($rdsInfo -and $rdsInfo.DBInstances.Count -gt 0) {
        $dbInst = $rdsInfo.DBInstances[0]
        $dbStatus = $dbInst.DBInstanceStatus
        Write-Host "RDS instance exists (Status: $dbStatus)" -ForegroundColor Green
        if ($dbInst.Endpoint) {
            $rdsEndpoint = $dbInst.Endpoint.Address
        }
    }
} catch {}

if (-not $rdsEndpoint) {
    Write-Host "Creating RDS PostgreSQL DB instance: $DbInstanceIdentifier (db.t3.micro, 20GB gp3)..."
    Write-Host "Note: RDS creation takes about 8-10 minutes on AWS." -ForegroundColor Yellow
    aws rds create-db-instance `
        --db-instance-identifier $DbInstanceIdentifier `
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
    Write-Host "RDS creation initiated. You can monitor it in the RDS Console." -ForegroundColor Green
} else {
    Write-Host "RDS Endpoint: $rdsEndpoint" -ForegroundColor Green
}

# 6. EC2 Instance
$ec2Ip = ""
if (-not $SkipEC2) {
    Write-Host "`n[6/6] Checking / Launching EC2 Instance..." -ForegroundColor Yellow
    
    # Check if instance already running
    $ec2Running = (aws ec2 describe-instances --filters "Name=tag:Name,Values=campusgigs-ec2" "Name=instance-state-name,Values=running,pending" --query "Reservations[0].Instances[0].PublicIpAddress" --output text --region $Region).Trim()
    if ($ec2Running -and $ec2Running -ne "None") {
        $ec2Ip = $ec2Running
        Write-Host "Found running EC2 instance with Public IP: $ec2Ip" -ForegroundColor Green
    } else {
        # Find Ubuntu 22.04 LTS AMI
        Write-Host "Finding Ubuntu 22.04 AMI in $Region..."
        $amiId = (aws ec2 describe-images --owners 099720109477 `
            --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" "Name=state,Values=available" `
            --query "reverse(sort_by(Images, &CreationDate))[0].ImageId" --output text --region $Region).Trim()
        Write-Host "Using Ubuntu 22.04 AMI: $amiId" -ForegroundColor Green

        Write-Host "Launching t2.micro EC2 with LabInstanceProfile..."
        $newInstance = aws ec2 run-instances `
            --image-id $amiId `
            --count 1 `
            --instance-type t2.micro `
            --key-name $KeyName `
            --security-group-ids $ec2SgId `
            --iam-instance-profile Name=LabInstanceProfile `
            --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=campusgigs-ec2}]" `
            --region $Region --output json | ConvertFrom-Json
        
        $instanceId = $newInstance.Instances[0].InstanceId
        Write-Host "Launched instance $instanceId. Waiting for Public IP..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
        $ec2Ip = (aws ec2 describe-instances --instance-ids $instanceId --query "Reservations[0].Instances[0].PublicIpAddress" --output text --region $Region).Trim()
        Write-Host "EC2 Public IP: $ec2Ip" -ForegroundColor Green
    }
}

# Summary and .env generation
Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "             PROVISIONING SUMMARY & NEXT STEPS             " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Region:             $Region"
Write-Host "S3 Bucket:          $BucketName"
Write-Host "EC2 Security Group: $ec2SgId"
Write-Host "RDS Security Group: $rdsSgId"
Write-Host "RDS Endpoint:       $(if ($rdsEndpoint) { $rdsEndpoint } else { '<Waiting for RDS creation to complete in AWS Console>' })"
Write-Host "EC2 Public IP:      $(if ($ec2Ip) { $ec2Ip } else { '<Not launched or pending>' })"

# Output env template
$jwt = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})
$envContent = @"
PORT=5000
NODE_ENV=production
JWT_SECRET=$jwt
DATABASE_URL=postgresql://postgres:$DbPassword@$(if ($rdsEndpoint) { $rdsEndpoint } else { '<RDS-ENDPOINT>' }):5432/campusgigs
DB_SSL=true
S3_BUCKET=$BucketName
AWS_REGION=$Region
ALLOWED_DOMAINS=ves.ac.in
CLIENT_ORIGIN=http://$(if ($ec2Ip) { $ec2Ip } else { '<EC2-PUBLIC-IP>' }):5000
"@

$envPath = Join-Path $PSScriptRoot "generated.server.env"
Set-Content -Path $envPath -Value $envContent -Force
Write-Host "`nGenerated environment configuration saved to: $envPath" -ForegroundColor Green
Write-Host "Once RDS is in 'Available' state, copy this to server/.env on your EC2 instance!" -ForegroundColor Yellow
