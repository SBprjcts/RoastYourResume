#!/bin/bash

# Resume Roaster - AWS Phase 1 Setup Script
# This script automates the AWS infrastructure setup for Phase 1

set -e  # Exit on any error

echo "🔥 Resume Roaster - AWS Infrastructure Setup (Phase 1) 🔥"
echo "============================================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get AWS Account ID
echo "📊 Getting AWS Account ID..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${RED}❌ Error: Could not retrieve AWS Account ID. Is AWS CLI configured?${NC}"
    echo "Run: aws configure"
    exit 1
fi

echo -e "${GREEN}✅ AWS Account ID: ${AWS_ACCOUNT_ID}${NC}"
echo ""

BUCKET_NAME="resume-roaster-uploads-${AWS_ACCOUNT_ID}"

# Step 1: Create S3 Bucket
echo "📦 Step 1/4: Creating S3 Bucket..."
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Bucket already exists: ${BUCKET_NAME}${NC}"
else
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region us-east-1
    echo -e "${GREEN}✅ S3 Bucket created: ${BUCKET_NAME}${NC}"
fi

# Enable encryption
echo "🔒 Enabling server-side encryption..."
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        },
        "BucketKeyEnabled": true
      }]
    }'
echo -e "${GREEN}✅ Encryption enabled${NC}"

# Block public access
echo "🔐 Blocking public access..."
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
      "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
echo -e "${GREEN}✅ Public access blocked${NC}"

# Configure CORS
echo "🌐 Configuring CORS..."
cat > /tmp/cors-config.json << 'EOF'
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
EOF

aws s3api put-bucket-cors \
    --bucket "$BUCKET_NAME" \
    --cors-configuration file:///tmp/cors-config.json
echo -e "${GREEN}✅ CORS configured${NC}"

# Set lifecycle policy
echo "⏰ Setting lifecycle policy (auto-delete after 7 days)..."
cat > /tmp/lifecycle-policy.json << 'EOF'
{
  "Rules": [
    {
      "Id": "DeleteUploadsAfter7Days",
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
EOF

aws s3api put-bucket-lifecycle-configuration \
    --bucket "$BUCKET_NAME" \
    --lifecycle-configuration file:///tmp/lifecycle-policy.json
echo -e "${GREEN}✅ Lifecycle policy set${NC}"
echo ""

# Step 2: Create IAM User
echo "👤 Step 2/4: Creating IAM User for Next.js..."
if aws iam get-user --user-name resume-roaster-nextjs 2>/dev/null; then
    echo -e "${YELLOW}⚠️  IAM user already exists: resume-roaster-nextjs${NC}"
else
    aws iam create-user --user-name resume-roaster-nextjs
    echo -e "${GREEN}✅ IAM user created: resume-roaster-nextjs${NC}"
fi

# Create IAM policy
echo "📜 Creating IAM policy..."
cat > /tmp/s3-upload-policy.json << EOF
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
EOF

POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/ResumeRoasterS3UploadPolicy"

if aws iam get-policy --policy-arn "$POLICY_ARN" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  IAM policy already exists${NC}"
else
    aws iam create-policy \
        --policy-name ResumeRoasterS3UploadPolicy \
        --policy-document file:///tmp/s3-upload-policy.json
    echo -e "${GREEN}✅ IAM policy created${NC}"
fi

# Attach policy to user
echo "🔗 Attaching policy to user..."
if aws iam list-attached-user-policies --user-name resume-roaster-nextjs | grep -q "ResumeRoasterS3UploadPolicy"; then
    echo -e "${YELLOW}⚠️  Policy already attached${NC}"
else
    aws iam attach-user-policy \
        --user-name resume-roaster-nextjs \
        --policy-arn "$POLICY_ARN"
    echo -e "${GREEN}✅ Policy attached to user${NC}"
fi

# Create access keys
echo "🔑 Creating access keys..."
if aws iam list-access-keys --user-name resume-roaster-nextjs | grep -q "AccessKeyId"; then
    echo -e "${YELLOW}⚠️  Access keys already exist. Skipping creation.${NC}"
    echo -e "${YELLOW}⚠️  If you need new keys, delete existing ones first:${NC}"
    echo "    aws iam list-access-keys --user-name resume-roaster-nextjs"
else
    ACCESS_KEY_OUTPUT=$(aws iam create-access-key --user-name resume-roaster-nextjs --output json)
    ACCESS_KEY_ID=$(echo "$ACCESS_KEY_OUTPUT" | jq -r '.AccessKey.AccessKeyId')
    SECRET_ACCESS_KEY=$(echo "$ACCESS_KEY_OUTPUT" | jq -r '.AccessKey.SecretAccessKey')

    echo -e "${GREEN}✅ Access keys created!${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  IMPORTANT: Save these credentials! They won't be shown again.${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "AWS_ACCESS_KEY_ID=${ACCESS_KEY_ID}"
    echo "AWS_SECRET_ACCESS_KEY=${SECRET_ACCESS_KEY}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Save to .env template
    cat > .env.template << EOF
# AWS Configuration
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}

# IAM User Credentials
AWS_ACCESS_KEY_ID=${ACCESS_KEY_ID}
AWS_SECRET_ACCESS_KEY=${SECRET_ACCESS_KEY}

# S3 Bucket Name
S3_BUCKET_NAME=${BUCKET_NAME}

# Placeholder for Phase 2 (will be populated after Lambda deployment)
LAMBDA_API_GATEWAY_URL=https://{api-id}.execute-api.us-east-1.amazonaws.com/prod
API_GATEWAY_KEY=your_api_gateway_key
EOF

    echo -e "${GREEN}✅ Credentials saved to .env.template${NC}"
fi
echo ""

# Step 3: Verify Bedrock Access
echo "🤖 Step 3/4: Verifying Bedrock Model Access..."
echo "⚠️  Note: Bedrock model access MUST be manually enabled via AWS Console"
echo "    Visit: https://console.aws.amazon.com/bedrock/home?region=us-east-1#/modelaccess"
echo ""

# Check Claude 3.5 Sonnet
echo "Checking Claude 3.5 Sonnet access..."
if aws bedrock get-foundation-model \
    --region us-east-1 \
    --model-identifier anthropic.claude-3-5-sonnet-20241022-v2:0 \
    2>/dev/null | grep -q "modelId"; then
    echo -e "${GREEN}✅ Claude 3.5 Sonnet access granted${NC}"
else
    echo -e "${RED}❌ Claude 3.5 Sonnet access NOT granted${NC}"
    echo -e "${YELLOW}   Please enable it in AWS Console (see link above)${NC}"
fi

# Check Titan Embeddings
echo "Checking Titan Embeddings access..."
if aws bedrock get-foundation-model \
    --region us-east-1 \
    --model-identifier amazon.titan-embed-text-v1 \
    2>/dev/null | grep -q "modelId"; then
    echo -e "${GREEN}✅ Titan Embeddings access granted${NC}"
else
    echo -e "${RED}❌ Titan Embeddings access NOT granted${NC}"
    echo -e "${YELLOW}   Please enable it in AWS Console (see link above)${NC}"
fi
echo ""

# Step 4: Verification
echo "🔍 Step 4/4: Running Verification Checks..."

# Verify S3 bucket
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo -e "${GREEN}✅ S3 bucket verified: ${BUCKET_NAME}${NC}"
else
    echo -e "${RED}❌ S3 bucket verification failed${NC}"
fi

# Verify IAM user
if aws iam get-user --user-name resume-roaster-nextjs 2>/dev/null; then
    echo -e "${GREEN}✅ IAM user verified: resume-roaster-nextjs${NC}"
else
    echo -e "${RED}❌ IAM user verification failed${NC}"
fi

# Verify CORS
if aws s3api get-bucket-cors --bucket "$BUCKET_NAME" 2>/dev/null | grep -q "localhost:3000"; then
    echo -e "${GREEN}✅ CORS configuration verified${NC}"
else
    echo -e "${RED}❌ CORS verification failed${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}🎉 Phase 1 Setup Complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Summary:"
echo "  • S3 Bucket: ${BUCKET_NAME}"
echo "  • IAM User: resume-roaster-nextjs"
echo "  • Region: us-east-1"
echo ""
echo "📝 Next Steps:"
echo "  1. Copy credentials from .env.template to frontend/.env.local"
echo "  2. Enable Bedrock models if not already done:"
echo "     https://console.aws.amazon.com/bedrock/home?region=us-east-1#/modelaccess"
echo "  3. Proceed to Phase 2: Backend Lambda Development"
echo ""
echo "🔥 Ready to roast some resumes! 🔥"
