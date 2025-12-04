# Resume Roaster - AWS Phase 1 Setup Script (PowerShell)
# This script automates the AWS infrastructure setup for Phase 1

$ErrorActionPreference = "Stop"

Write-Host "*** Resume Roaster - AWS Infrastructure Setup (Phase 1) ***" -ForegroundColor Yellow
Write-Host "============================================================"
Write-Host ""

# Get AWS Account ID
Write-Host "[INFO] Getting AWS Account ID..." -ForegroundColor Cyan
try {
    $AWS_ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text)
    if (-not $AWS_ACCOUNT_ID) {
        throw "Could not retrieve AWS Account ID"
    }
    Write-Host "[OK] AWS Account ID: $AWS_ACCOUNT_ID" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Could not retrieve AWS Account ID. Is AWS CLI configured?" -ForegroundColor Red
    Write-Host "Run: aws configure" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

$BUCKET_NAME = "resume-roaster-uploads-$AWS_ACCOUNT_ID"

# Step 1: Create S3 Bucket
Write-Host "[STEP 1/4] Creating S3 Bucket..." -ForegroundColor Cyan

try {
    aws s3api head-bucket --bucket $BUCKET_NAME 2>$null
    Write-Host "[WARN] Bucket already exists: $BUCKET_NAME" -ForegroundColor Yellow
} catch {
    aws s3api create-bucket --bucket $BUCKET_NAME --region us-east-1
    Write-Host "[OK] S3 Bucket created: $BUCKET_NAME" -ForegroundColor Green
}

# Enable encryption
Write-Host "[SECURE] Enabling server-side encryption..." -ForegroundColor Cyan
$encryptionPath = "$env:TEMP\encryption-config.json"
@"
{
  "Rules": [{
    "ApplyServerSideEncryptionByDefault": {
      "SSEAlgorithm": "AES256"
    },
    "BucketKeyEnabled": true
  }]
}
"@ | Set-Content -Path $encryptionPath -NoNewline

aws s3api put-bucket-encryption --bucket $BUCKET_NAME --server-side-encryption-configuration "file://$encryptionPath"
Write-Host "[OK] Encryption enabled" -ForegroundColor Green

# Block public access
Write-Host "[SECURE] Blocking public access..." -ForegroundColor Cyan
aws s3api put-public-access-block --bucket $BUCKET_NAME --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
Write-Host "[OK] Public access blocked" -ForegroundColor Green

# Configure CORS
Write-Host "[WEB] Configuring CORS..." -ForegroundColor Cyan
$corsPath = "$env:TEMP\cors-config.json"
@"
{
  "CORSRules": [
    {
      "AllowedHeaders": ["*"],
      "AllowedMethods": ["PUT", "POST"],
      "AllowedOrigins": [
        "http://localhost:3000",
        "https://*.vercel.app"
      ],
      "ExposeHeaders": ["ETag"],
      "MaxAgeSeconds": 3000
    }
  ]
}
"@ | Set-Content -Path $corsPath -NoNewline

aws s3api put-bucket-cors --bucket $BUCKET_NAME --cors-configuration "file://$corsPath"
Write-Host "[OK] CORS configured" -ForegroundColor Green

# Set lifecycle policy
Write-Host "[LIFECYCLE] Setting lifecycle policy (auto-delete after 7 days)..." -ForegroundColor Cyan
$lifecyclePath = "$env:TEMP\lifecycle-policy.json"
@"
{
  "Rules": [
    {
      "ID": "DeleteUploadsAfter7Days",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "uploads/"
      },
      "Expiration": {
        "Days": 7
      }
    }
  ]
}
"@ | Set-Content -Path $lifecyclePath -NoNewline

aws s3api put-bucket-lifecycle-configuration --bucket $BUCKET_NAME --lifecycle-configuration "file://$lifecyclePath"
Write-Host "[OK] Lifecycle policy set" -ForegroundColor Green
Write-Host ""

# Step 2: Create IAM User
Write-Host "[STEP 2/4] Creating IAM User for Next.js..." -ForegroundColor Cyan

try {
    aws iam get-user --user-name resume-roaster-nextjs 2>$null | Out-Null
    Write-Host "[WARN] IAM user already exists: resume-roaster-nextjs" -ForegroundColor Yellow
} catch {
    aws iam create-user --user-name resume-roaster-nextjs | Out-Null
    Write-Host "[OK] IAM user created: resume-roaster-nextjs" -ForegroundColor Green
}

# Create IAM policy
Write-Host "[IAM] Creating IAM policy..." -ForegroundColor Cyan
$policyPath = "$env:TEMP\s3-upload-policy.json"
@"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowS3PutObject",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:PutObjectAcl"
      ],
      "Resource": "arn:aws:s3:::resume-roaster-uploads-*/*"
    }
  ]
}
"@ | Set-Content -Path $policyPath -NoNewline

$POLICY_ARN = "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/ResumeRoasterS3UploadPolicy"

try {
    aws iam get-policy --policy-arn $POLICY_ARN 2>$null | Out-Null
    Write-Host "[WARN] IAM policy already exists" -ForegroundColor Yellow
} catch {
    aws iam create-policy --policy-name ResumeRoasterS3UploadPolicy --policy-document "file://$policyPath" | Out-Null
    Write-Host "[OK] IAM policy created" -ForegroundColor Green
}

# Attach policy to user
Write-Host "[IAM] Attaching policy to user..." -ForegroundColor Cyan
$attachedPolicies = aws iam list-attached-user-policies --user-name resume-roaster-nextjs 2>$null | ConvertFrom-Json

if ($attachedPolicies.AttachedPolicies | Where-Object { $_.PolicyName -eq "ResumeRoasterS3UploadPolicy" }) {
    Write-Host "[WARN] Policy already attached" -ForegroundColor Yellow
} else {
    aws iam attach-user-policy --user-name resume-roaster-nextjs --policy-arn $POLICY_ARN
    Write-Host "[OK] Policy attached to user" -ForegroundColor Green
}

# Create access keys
Write-Host "[KEYS] Creating access keys..." -ForegroundColor Cyan
$existingKeys = aws iam list-access-keys --user-name resume-roaster-nextjs 2>$null | ConvertFrom-Json

if ($existingKeys.AccessKeyMetadata.Count -gt 0) {
    Write-Host "[WARN] Access keys already exist. Skipping creation." -ForegroundColor Yellow
    Write-Host "[WARN] If you need new keys, delete existing ones first:" -ForegroundColor Yellow
    Write-Host "    aws iam list-access-keys --user-name resume-roaster-nextjs" -ForegroundColor White
} else {
    $accessKeyOutput = aws iam create-access-key --user-name resume-roaster-nextjs --output json | ConvertFrom-Json
    $ACCESS_KEY_ID = $accessKeyOutput.AccessKey.AccessKeyId
    $SECRET_ACCESS_KEY = $accessKeyOutput.AccessKey.SecretAccessKey

    Write-Host "[OK] Access keys created!" -ForegroundColor Green
    Write-Host ""
    Write-Host "[IMPORTANT] Save these credentials! They won't be shown again." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "AWS_ACCESS_KEY_ID=$ACCESS_KEY_ID" -ForegroundColor White
    Write-Host "AWS_SECRET_ACCESS_KEY=$SECRET_ACCESS_KEY" -ForegroundColor White
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host ""

    # Save to .env template
    $envTemplatePath = ".env.template"
@"
# AWS Configuration
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=$AWS_ACCOUNT_ID

# IAM User Credentials
AWS_ACCESS_KEY_ID=$ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY=$SECRET_ACCESS_KEY

# S3 Bucket Name
S3_BUCKET_NAME=$BUCKET_NAME

# Placeholder for Phase 2 (will be populated after Lambda deployment)
LAMBDA_API_GATEWAY_URL=https://{api-id}.execute-api.us-east-1.amazonaws.com/prod
API_GATEWAY_KEY=your_api_gateway_key
"@ | Set-Content -Path $envTemplatePath -NoNewline

    Write-Host "[OK] Credentials saved to .env.template" -ForegroundColor Green
}

Write-Host ""

# Step 3: Verify Bedrock Access
Write-Host "[STEP 3/4] Verifying Bedrock Model Access..." -ForegroundColor Cyan
Write-Host "[NOTE] Bedrock model access MUST be manually enabled via AWS Console" -ForegroundColor Yellow
Write-Host "    Visit: https://console.aws.amazon.com/bedrock/home?region=us-east-1#/modelaccess" -ForegroundColor White
Write-Host ""

# Check Claude 3.5 Sonnet
Write-Host "Checking Claude 3.5 Sonnet access..." -ForegroundColor Cyan
try {
    $claudeModel = aws bedrock get-foundation-model --region us-east-1 --model-identifier anthropic.claude-3-5-sonnet-20241022-v2:0 2>$null | ConvertFrom-Json
    if ($claudeModel.modelDetails.modelId) {
        Write-Host "[OK] Claude 3.5 Sonnet access granted" -ForegroundColor Green
    }
} catch {
    Write-Host "[ERROR] Claude 3.5 Sonnet access NOT granted" -ForegroundColor Red
    Write-Host "   Please enable it in AWS Console (see link above)" -ForegroundColor Yellow
}

# Check Titan Embeddings
Write-Host "Checking Titan Embeddings access..." -ForegroundColor Cyan
try {
    $titanModel = aws bedrock get-foundation-model --region us-east-1 --model-identifier amazon.titan-embed-text-v1 2>$null | ConvertFrom-Json
    if ($titanModel.modelDetails.modelId) {
        Write-Host "[OK] Titan Embeddings access granted" -ForegroundColor Green
    }
} catch {
    Write-Host "[ERROR] Titan Embeddings access NOT granted" -ForegroundColor Red
    Write-Host "   Please enable it in AWS Console (see link above)" -ForegroundColor Yellow
}

Write-Host ""

# Step 4: Verification
Write-Host "[STEP 4/4] Running Verification Checks..." -ForegroundColor Cyan

# Verify S3 bucket
try {
    aws s3api head-bucket --bucket $BUCKET_NAME 2>$null
    Write-Host "[OK] S3 bucket verified: $BUCKET_NAME" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] S3 bucket verification failed" -ForegroundColor Red
}

# Verify IAM user
try {
    aws iam get-user --user-name resume-roaster-nextjs 2>$null | Out-Null
    Write-Host "[OK] IAM user verified: resume-roaster-nextjs" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] IAM user verification failed" -ForegroundColor Red
}

# Verify CORS
try {
    $corsCheck = aws s3api get-bucket-cors --bucket $BUCKET_NAME 2>$null
    if ($corsCheck -match "localhost:3000") {
        Write-Host "[OK] CORS configuration verified" -ForegroundColor Green
    }
} catch {
    Write-Host "[ERROR] CORS verification failed" -ForegroundColor Red
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "*** Phase 1 Setup Complete! ***" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[SUMMARY]" -ForegroundColor Yellow
Write-Host "  • S3 Bucket: $BUCKET_NAME" -ForegroundColor White
Write-Host "  • IAM User: resume-roaster-nextjs" -ForegroundColor White
Write-Host "  • Region: us-east-1" -ForegroundColor White
Write-Host ""
Write-Host "[NEXT STEPS]" -ForegroundColor Yellow
Write-Host "  1. Copy credentials from .env.template to frontend/.env.local" -ForegroundColor White
Write-Host "  2. Enable Bedrock models if not already done:" -ForegroundColor White
Write-Host "     https://console.aws.amazon.com/bedrock/home?region=us-east-1#/modelaccess" -ForegroundColor White
Write-Host "  3. Proceed to Phase 2: Backend Lambda Development" -ForegroundColor White
Write-Host ""
Write-Host "*** Ready to roast some resumes! ***" -ForegroundColor Yellow
