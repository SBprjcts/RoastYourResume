# AWS Infrastructure Setup Guide (Phase 1)

This guide walks you through setting up the AWS infrastructure for the Resume Roaster application.

---

## Prerequisites

- AWS Account with administrator access
- AWS CLI installed and configured ([Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- Your AWS Account ID (find it by running `aws sts get-caller-identity`)

---

## Step 1: Create S3 Bucket for Resume Uploads

### 1.1 Get Your AWS Account ID

```bash
aws sts get-caller-identity --query Account --output text
```

Save this account ID - you'll use it for the bucket name.

### 1.2 Create the S3 Bucket

Replace `{account-id}` with your actual AWS account ID:

```bash
# Set your account ID as a variable (replace with actual ID)
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create the bucket in us-east-1
aws s3api create-bucket \
  --bucket resume-roaster-uploads-${AWS_ACCOUNT_ID} \
  --region us-east-1
```

**Expected Output:**
```json
{
    "Location": "/resume-roaster-uploads-123456789012"
}
```

### 1.3 Enable Server-Side Encryption

```bash
aws s3api put-bucket-encryption \
  --bucket resume-roaster-uploads-${AWS_ACCOUNT_ID} \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      },
      "BucketKeyEnabled": true
    }]
  }'
```

### 1.4 Block Public Access (Security Best Practice)

```bash
aws s3api put-public-access-block \
  --bucket resume-roaster-uploads-${AWS_ACCOUNT_ID} \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

### 1.5 Configure CORS for Frontend Access

Create a file named `cors-config.json`:

```json
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
```

Apply the CORS configuration:

```bash
aws s3api put-bucket-cors \
  --bucket resume-roaster-uploads-${AWS_ACCOUNT_ID} \
  --cors-configuration file://cors-config.json
```

**Verify CORS configuration:**
```bash
aws s3api get-bucket-cors \
  --bucket resume-roaster-uploads-${AWS_ACCOUNT_ID}
```

### 1.6 Set Lifecycle Policy (Auto-delete uploads after 7 days)

Create a file named `lifecycle-policy.json`:

```json
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
```

Apply the lifecycle policy:

```bash
aws s3api put-bucket-lifecycle-configuration \
  --bucket resume-roaster-uploads-${AWS_ACCOUNT_ID} \
  --lifecycle-configuration file://lifecycle-policy.json
```

---

## Step 2: Create IAM User for Next.js Frontend

### 2.1 Create IAM User

```bash
aws iam create-user --user-name resume-roaster-nextjs
```

### 2.2 Create IAM Policy for S3 Upload Access

Create a file named `s3-upload-policy.json`:

```json
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
```

Create the policy:

```bash
aws iam create-policy \
  --policy-name ResumeRoasterS3UploadPolicy \
  --policy-document file://s3-upload-policy.json
```

**Save the Policy ARN** from the output - it will look like:
```
arn:aws:iam::123456789012:policy/ResumeRoasterS3UploadPolicy
```

### 2.3 Attach Policy to User

Replace `{policy-arn}` with the ARN from the previous step:

```bash
aws iam attach-user-policy \
  --user-name resume-roaster-nextjs \
  --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/ResumeRoasterS3UploadPolicy
```

### 2.4 Create Access Keys

```bash
aws iam create-access-key --user-name resume-roaster-nextjs
```

**IMPORTANT:** Save the output! You'll need these credentials for your Next.js `.env.local` file:

```json
{
  "AccessKey": {
    "AccessKeyId": "AKIAIOSFODNN7EXAMPLE",
    "SecretAccessKey": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
    "Status": "Active",
    "CreateDate": "2025-01-01T00:00:00Z"
  }
}
```

**Add these to your `.env.local` file later:**
```bash
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

---

## Step 3: Enable AWS Bedrock Model Access

### 3.1 Check Bedrock Availability in us-east-1

```bash
aws bedrock list-foundation-models \
  --region us-east-1 \
  --query 'modelSummaries[?contains(modelId, `claude`) || contains(modelId, `titan`)].modelId' \
  --output table
```

### 3.2 Enable Model Access via AWS Console

**AWS Bedrock model access MUST be enabled via the AWS Console (cannot be done via CLI).**

1. **Navigate to AWS Bedrock Console:**
   - Go to: https://console.aws.amazon.com/bedrock/home?region=us-east-1#/modelaccess
   - Or search for "Bedrock" in the AWS Console

2. **Request Model Access:**
   - Click **"Manage model access"** in the left sidebar
   - Find and enable the following models:
     - ✅ **Anthropic - Claude 3.5 Sonnet v2** (`anthropic.claude-3-5-sonnet-20241022-v2:0`)
     - ✅ **Amazon - Titan Embeddings G1 - Text** (`amazon.titan-embed-text-v1`)

3. **Submit Access Request:**
   - Click **"Request model access"** for each model
   - Accept the EULA (End User License Agreement)
   - Click **"Submit"**

4. **Wait for Approval (Usually Instant):**
   - Status should change from "Pending" → "Access granted"
   - This typically takes less than 1 minute

### 3.3 Verify Model Access via CLI

```bash
# Check Claude 3.5 Sonnet access
aws bedrock list-foundation-models \
  --region us-east-1 \
  --query 'modelSummaries[?contains(modelId, `claude-3-5-sonnet`)].{ModelId:modelId, Status:modelLifecycle.status}' \
  --output table

# Check Titan Embeddings access
aws bedrock list-foundation-models \
  --region us-east-1 \
  --query 'modelSummaries[?contains(modelId, `titan-embed`)].{ModelId:modelId, Status:modelLifecycle.status}' \
  --output table
```

### 3.4 Test Bedrock API Access (Optional)

Create a test file `test-bedrock.json`:

```json
{
  "anthropic_version": "bedrock-2023-05-31",
  "max_tokens": 100,
  "messages": [
    {
      "role": "user",
      "content": "Say 'Bedrock is working!' in a Gen Z way"
    }
  ]
}
```

Test Claude 3.5 Sonnet:

```bash
aws bedrock-runtime invoke-model \
  --region us-east-1 \
  --model-id anthropic.claude-3-5-sonnet-20241022-v2:0 \
  --body file://test-bedrock.json \
  --cli-binary-format raw-in-base64-out \
  output.json

cat output.json
```

Test Titan Embeddings:

```bash
echo '{"inputText": "Hello world"}' > titan-test.json

aws bedrock-runtime invoke-model \
  --region us-east-1 \
  --model-id amazon.titan-embed-text-v1 \
  --body file://titan-test.json \
  --cli-binary-format raw-in-base64-out \
  titan-output.json

cat titan-output.json
```

---

## Step 4: Verification Checklist

Run this checklist to ensure everything is set up correctly:

### ✅ S3 Bucket Verification

```bash
# 1. Check bucket exists
aws s3 ls | grep resume-roaster-uploads

# 2. Verify CORS configuration
aws s3api get-bucket-cors --bucket resume-roaster-uploads-${AWS_ACCOUNT_ID}

# 3. Verify encryption
aws s3api get-bucket-encryption --bucket resume-roaster-uploads-${AWS_ACCOUNT_ID}

# 4. Verify lifecycle policy
aws s3api get-bucket-lifecycle-configuration --bucket resume-roaster-uploads-${AWS_ACCOUNT_ID}
```

### ✅ IAM User Verification

```bash
# 1. Check user exists
aws iam get-user --user-name resume-roaster-nextjs

# 2. List attached policies
aws iam list-attached-user-policies --user-name resume-roaster-nextjs

# 3. List access keys
aws iam list-access-keys --user-name resume-roaster-nextjs
```

### ✅ Bedrock Access Verification

```bash
# 1. Verify Claude 3.5 Sonnet access
aws bedrock get-foundation-model \
  --region us-east-1 \
  --model-identifier anthropic.claude-3-5-sonnet-20241022-v2:0

# 2. Verify Titan Embeddings access
aws bedrock get-foundation-model \
  --region us-east-1 \
  --model-identifier amazon.titan-embed-text-v1
```

---

## Environment Variables Summary

After completing Phase 1, you should have these values ready for your `.env.local` file:

```bash
# AWS Configuration
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=123456789012  # Your actual account ID

# IAM User Credentials (from Step 2.4)
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

# S3 Bucket Name
S3_BUCKET_NAME=resume-roaster-uploads-123456789012

# Placeholder for Phase 2 (will be populated after Lambda deployment)
LAMBDA_API_GATEWAY_URL=https://{api-id}.execute-api.us-east-1.amazonaws.com/prod
API_GATEWAY_KEY=your_api_gateway_key
```

---

## Cleanup (If You Need to Start Over)

If you need to delete everything and start fresh:

```bash
# Delete S3 bucket contents and bucket
aws s3 rm s3://resume-roaster-uploads-${AWS_ACCOUNT_ID} --recursive
aws s3api delete-bucket --bucket resume-roaster-uploads-${AWS_ACCOUNT_ID} --region us-east-1

# Delete IAM user access keys
aws iam list-access-keys --user-name resume-roaster-nextjs --query 'AccessKeyMetadata[].AccessKeyId' --output text | \
  xargs -I {} aws iam delete-access-key --user-name resume-roaster-nextjs --access-key-id {}

# Detach policy from user
aws iam detach-user-policy \
  --user-name resume-roaster-nextjs \
  --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/ResumeRoasterS3UploadPolicy

# Delete IAM user
aws iam delete-user --user-name resume-roaster-nextjs

# Delete IAM policy
aws iam delete-policy --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/ResumeRoasterS3UploadPolicy
```

---

## Troubleshooting

### Issue: "AccessDenied" when creating bucket

**Solution:** Ensure your AWS CLI is configured with credentials that have admin access:
```bash
aws configure
aws sts get-caller-identity
```

### Issue: "BucketAlreadyExists" error

**Solution:** S3 bucket names are globally unique. Use your account ID in the bucket name:
```bash
aws sts get-caller-identity --query Account --output text
```

### Issue: Bedrock models not available

**Solution:**
1. Ensure you're in `us-east-1` region
2. Request model access via AWS Console (see Step 3.2)
3. Wait 1-2 minutes for access to be granted

### Issue: CORS errors during testing

**Solution:**
1. Verify CORS config includes your frontend domain
2. Update CORS config to add your Vercel URL when deployed
3. Use `aws s3api put-bucket-cors` to update CORS configuration

---

## Next Steps

Once Phase 1 is complete, proceed to:
- **Phase 2:** Backend Lambda Development (create SAM template, Lambda handler, RAG pipeline)

---

**Phase 1 Complete! 🎉**

You now have:
- ✅ S3 bucket with CORS and encryption configured
- ✅ IAM user with S3 upload permissions
- ✅ Bedrock model access for Claude 3.5 Sonnet and Titan Embeddings
- ✅ AWS credentials ready for `.env.local`
