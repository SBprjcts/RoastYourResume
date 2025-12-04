# Resume Roaster - Quick Start Guide 🔥

Get your Resume Roaster app up and running in minutes!

---

## Prerequisites Checklist

Before you begin, ensure you have:

- [ ] AWS Account ([Sign up here](https://aws.amazon.com/free/))
- [ ] AWS CLI installed ([Install guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- [ ] AWS CLI configured with credentials (`aws configure`)
- [ ] Node.js 18+ installed ([Download](https://nodejs.org/))
- [ ] Git installed

---

## Phase 1: AWS Infrastructure Setup (15 minutes)

### Option A: Automated Setup (Recommended)

**On Windows (PowerShell):**
```powershell
cd C:\Users\saifb\Downloads\RoastYourResume
.\scripts\setup-aws-phase1.ps1
```

**On Mac/Linux (Bash):**
```bash
cd /path/to/RoastYourResume
chmod +x scripts/setup-aws-phase1.sh
./scripts/setup-aws-phase1.sh
```

### Option B: Manual Setup

Follow the detailed guide: [AWS_SETUP_GUIDE.md](AWS_SETUP_GUIDE.md)

### What This Does:

✅ Creates S3 bucket for PDF uploads
✅ Configures CORS, encryption, and lifecycle policies
✅ Creates IAM user with S3 upload permissions
✅ Generates AWS access keys
✅ Saves credentials to `.env.template`

### Important: Enable Bedrock Models

**This step MUST be done manually via AWS Console:**

1. Visit: https://console.aws.amazon.com/bedrock/home?region=us-east-1#/modelaccess
2. Click **"Manage model access"**
3. Enable:
   - ✅ **Anthropic - Claude 3.5 Sonnet v2**
   - ✅ **Amazon - Titan Embeddings G1 - Text**
4. Click **"Request model access"**
5. Accept EULA and submit
6. Wait ~1 minute for approval

---

## Phase 2: Backend Lambda Development (Coming Soon)

This phase will create:
- AWS SAM template for infrastructure
- Lambda handler function
- RAG pipeline with LangChain
- API Gateway for frontend access

**Status:** 📋 Planned (not yet implemented)

---

## Phase 3: Frontend Next.js Setup (Coming Soon)

This phase will create:
- Next.js 14 app with TypeScript
- API routes for S3 uploads and roast requests
- Clean, Gen Z-friendly UI
- Fire emoji loading animation 🔥

**Status:** 📋 Planned (not yet implemented)

---

## Environment Variables

After Phase 1 completes, you'll have a `.env.template` file with:

```bash
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=123456789012
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
S3_BUCKET_NAME=resume-roaster-uploads-123456789012
LAMBDA_API_GATEWAY_URL=https://{api-id}.execute-api.us-east-1.amazonaws.com/prod
API_GATEWAY_KEY=your_api_gateway_key
```

**Copy this to `frontend/.env.local` when you create the frontend.**

---

## Project Structure

```
RoastYourResume/
├── Backend/
│   ├── requirements.txt          ✅ Created
│   ├── handler.py                📋 Coming in Phase 2
│   ├── rag_pipeline.py           📋 Coming in Phase 2
│   └── template.yaml             📋 Coming in Phase 2
│
├── frontend/                     📋 Coming in Phase 3
│   ├── src/
│   │   └── app/
│   │       └── api/
│   │           ├── upload/
│   │           └── roast/
│   ├── .env.local
│   └── package.json
│
├── scripts/
│   ├── setup-aws-phase1.sh       ✅ Created
│   └── setup-aws-phase1.ps1      ✅ Created
│
├── AWS_SETUP_GUIDE.md            ✅ Created
├── CLAUDE.md                     ✅ Updated
├── QUICK_START.md                ✅ This file
└── README.md
```

---

## Troubleshooting

### AWS CLI Not Found

**Solution:**
```bash
# Check if AWS CLI is installed
aws --version

# If not installed, download from:
# https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
```

### AWS CLI Not Configured

**Solution:**
```bash
aws configure

# Enter when prompted:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region: us-east-1
# - Default output format: json
```

### Bedrock Models Not Available

**Solution:**
1. Ensure you're in `us-east-1` region
2. Manually enable models via AWS Console (see Phase 1 guide)
3. Wait 1-2 minutes for access to be granted

### S3 Bucket Name Already Exists

**Solution:** S3 bucket names are globally unique. The scripts use your AWS Account ID to ensure uniqueness. If you still get this error, someone else may be using a similar name. Modify the bucket name in the script.

---

## Cost Estimates

### Development (Testing with ~10 resumes/day):
- **Monthly Cost:** ~$1-2
  - S3 storage: < $0.10
  - Lambda compute: ~$0.50
  - Bedrock API calls: ~$1.00
  - API Gateway: < $0.05

### Production (100 resumes/day):
- **Monthly Cost:** ~$30-40
  - S3 storage: ~$1
  - Lambda compute: ~$5
  - Bedrock API calls: ~$30
  - API Gateway: ~$0.50

**Note:** AWS Free Tier covers much of the development costs!

---

## Next Steps After Phase 1

1. ✅ Verify all AWS resources are created
2. ✅ Save your AWS credentials from `.env.template`
3. ⏳ Wait for Phase 2: Backend Lambda Development
4. ⏳ Wait for Phase 3: Frontend Next.js Setup
5. 🚀 Deploy and start roasting resumes!

---

## Getting Help

- **AWS Setup Issues:** See [AWS_SETUP_GUIDE.md](AWS_SETUP_GUIDE.md)
- **Architecture Questions:** See [CLAUDE.md](CLAUDE.md)
- **Project Status:** Check the "Current Status" section in CLAUDE.md

---

## Learning Resources

Want to understand the tech stack better?

- **AWS Lambda:** https://aws.amazon.com/lambda/getting-started/
- **AWS Bedrock:** https://docs.aws.amazon.com/bedrock/
- **LangChain:** https://python.langchain.com/docs/get_started/introduction
- **Next.js 14:** https://nextjs.org/docs
- **AWS SAM:** https://docs.aws.amazon.com/serverless-application-model/

---

**Ready to roast some resumes? Let's go! 🔥**
