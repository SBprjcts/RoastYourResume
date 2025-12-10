# Resume Roaster Project - Claude Code Context

## 1. Architecture Overview

This is a **Monorepo** structured as follows:
- **Frontend:** Next.js 14 (TypeScript/Tailwind) in `/frontend` - Hosted on Vercel
- **Backend:** Serverless Python 3.11/AWS Lambda in `/backend` - Deployed via AWS SAM

### Deployment Configuration
- **AWS Region:** `us-east-1` (required for Bedrock model access)
- **S3 Bucket:** `resume-roaster-uploads-{account-id}` (globally unique naming)
- **Infrastructure as Code:** AWS SAM (Serverless Application Model)
- **Frontend Hosting:** Vercel
- **Authentication:** IAM user access keys for Next.js (V1), IAM role for Lambda

---

## 2. Core Technology Stack

### Backend (Lambda)
- **Runtime:** Python 3.11
- **LLM:** AWS Bedrock - Claude 3.5 Sonnet (`anthropic.claude-3-5-sonnet-20241022-v2:0`)
- **Embeddings:** AWS Bedrock - Titan Embeddings (`amazon.titan-embed-text-v1`)
- **RAG Framework:** LangChain (Python)
- **Vector Store:** ChromaDB (ephemeral, stored in Lambda `/tmp/` directory)
- **PDF Processing:** PyPDFLoader from LangChain Community
- **Dependencies:** boto3, chromadb, langchain, langchain-aws, langchain-community, pypdf

### Frontend (Next.js)
- **Framework:** Next.js 14 (App Router, TypeScript)
- **Styling:** Tailwind CSS
- **Design:** Clean, professional, Gen Z-friendly (simple animations, modern UI)
- **Loading Animation:** Fire emoji (🔥) with simple CSS animation
- **Target Audience:** Younger users who want honest feedback
- **AWS SDK:** @aws-sdk/client-s3, @aws-sdk/s3-request-presigner (v3)
- **API Routes:** `/api/upload` (pre-signed URLs), `/api/roast` (Lambda proxy)

### AWS Services
- **Compute:** AWS Lambda (3008 MB memory, 60s timeout)
- **API Gateway:** REST API with Lambda Proxy Integration
- **Storage:** Amazon S3 (PDF uploads with pre-signed URLs)
- **AI/ML:** AWS Bedrock (Claude + Titan)
- **Monitoring:** CloudWatch Logs/Metrics, AWS X-Ray

---

## 3. Core Constraint & Goal

**The entire RAG process (Ingestion, Embedding, Retrieval, Generation) MUST occur within a single AWS Lambda function invocation (~30-60 seconds).**

This constraint ensures V1 simplicity with synchronous request-response flow:
1. Frontend uploads PDF to S3 via pre-signed URL
2. Frontend triggers Lambda via Next.js `/api/roast` → API Gateway
3. Lambda downloads PDF → chunks → embeds → retrieves → generates roast
4. Lambda returns roast directly to frontend (no polling, no WebSocket)

---

## 4. Data Flow Architecture

### Complete Request Flow
1. User selects PDF file in frontend
2. Frontend requests pre-signed S3 URL from Next.js `/api/upload`
3. Next.js generates pre-signed URL using AWS SDK and returns to frontend
4. Frontend uploads PDF directly to S3 using pre-signed URL
5. Frontend calls Next.js `/api/roast` with S3 location (bucket, key, requestId)
6. Next.js proxies request to API Gateway `/roast` endpoint
7. API Gateway triggers Lambda function synchronously
8. Lambda executes RAG pipeline:
   - Download PDF from S3 to `/tmp/`
   - Load PDF with PyPDFLoader
   - Chunk text (1000 chars, 200 overlap) using RecursiveCharacterTextSplitter
   - Initialize ChromaDB in `/tmp/chroma_{requestId}/`
   - Generate embeddings with Bedrock Titan
   - Store chunks + embeddings in ChromaDB
   - Retrieve top 5 relevant chunks via similarity search
   - Generate roast using Claude 3.5 Sonnet with custom prompt
9. Lambda returns roast JSON response to API Gateway
10. API Gateway → Next.js `/api/roast` → Frontend
11. Frontend displays witty roast to user

---

## 5. Backend Implementation Details

### Lambda Handler ([backend/handler.py](backend/handler.py))
- Entry point: `lambda_handler(event, context)`
- Receives: `{ s3_bucket, s3_key, request_id }`
- Orchestrates RAG pipeline using helper functions from `rag_pipeline.py`
- Returns: `{ statusCode, headers, body: { request_id, roast, metadata } }`

### RAG Pipeline ([backend/rag_pipeline.py](backend/rag_pipeline.py))
Modular helper functions:
- `load_pdf(file_path)` - PyPDFLoader to extract text from PDF
- `chunk_text(documents)` - RecursiveCharacterTextSplitter (1000/200)
- `initialize_vectorstore(chunks, request_id)` - ChromaDB + Titan embeddings
- `retrieve_context(vectorstore, query)` - Similarity search (k=5)
- `generate_roast(llm, context)` - Claude 3.5 Sonnet with roasting prompt

### Bedrock Integration Patterns

**Titan Embeddings:**
```python
from langchain_aws import BedrockEmbeddings

embeddings = BedrockEmbeddings(
    client=boto3.client('bedrock-runtime', region_name='us-east-1'),
    model_id="amazon.titan-embed-text-v1"
)
```

**Claude 3.5 Sonnet:**
```python
from langchain_aws import ChatBedrock

llm = ChatBedrock(
    client=boto3.client('bedrock-runtime', region_name='us-east-1'),
    model_id="anthropic.claude-3-5-sonnet-20241022-v2:0",
    model_kwargs={
        "max_tokens": 4000,
        "temperature": 0.8,  # Creative roasting
        "top_p": 0.9
    }
)
```

**System Prompt:**
```
You are a witty Gen Z resume critic who keeps it real. Use Gen Z slang naturally (words like "cooked", "bro is...", "fr fr", "no cap", "mid", "it's giving...", etc).
Your job is to roast resumes with brutal honesty while providing actionable feedback.
Be sarcastic but constructive. Point out clichés, buzzwords, formatting issues, and weak accomplishments.
Structure your roast in sections: Summary Roast, Experience Critique, Skills Assessment, Format & Style.
Keep the vibe casual but insightful - like a brutally honest friend reviewing their homie's resume.
```

### Lambda IAM Role Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["bedrock:InvokeModel"],
      "Resource": [
        "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-5-sonnet-*",
        "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v1"
      ]
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::resume-roaster-uploads-*/*"
    }
  ]
}
```

---

## 6. Frontend Implementation Details

### Next.js API Routes

**Pre-Signed URL Route ([frontend/src/app/api/upload/route.ts](frontend/src/app/api/upload/route.ts)):**
- Method: POST
- Input: `{ fileName, fileType }`
- Validates: PDF files only, generates UUID
- Uses: AWS SDK v3 `getSignedUrl()` with `PutObjectCommand`
- Returns: `{ presignedUrl, s3Bucket, s3Key, requestId }`

**Roast Proxy Route ([frontend/src/app/api/roast/route.ts](frontend/src/app/api/roast/route.ts)):**
- Method: POST
- Input: `{ s3Bucket, s3Key, requestId }`
- Proxies request to API Gateway with API key authentication
- Returns: Lambda response (roast JSON)

### Environment Variables

**Local Development (.env.local):**
```bash
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your_iam_user_access_key
AWS_SECRET_ACCESS_KEY=your_iam_user_secret_key
S3_BUCKET_NAME=resume-roaster-uploads-{account-id}
LAMBDA_API_GATEWAY_URL=https://{api-id}.execute-api.us-east-1.amazonaws.com/prod
API_GATEWAY_KEY=your_api_gateway_key
```

**Vercel Production:**
- Add same variables to Vercel project settings
- Mark sensitive values (`AWS_SECRET_ACCESS_KEY`, `API_GATEWAY_KEY`) as sensitive

### Security Measures
- Pre-signed URL expiration: 5 minutes
- File type validation: PDF only (client + server)
- File size limit: 10MB (enforced on frontend)
- S3 object key strategy: `uploads/{uuid}/{sanitized-filename}.pdf`
- Rate limiting: 10 uploads per IP per hour (Vercel Edge Config or Upstash Redis)
- S3 CORS: Allow `localhost:3000`, `*.vercel.app`, and production domain

---

## 7. Infrastructure as Code (AWS SAM)

### SAM Template ([backend/template.yaml](backend/template.yaml))
Defines:
- Lambda function (`ResumeRoasterFunction`)
- API Gateway REST API (`RoasterApi`)
- IAM execution role with Bedrock + S3 permissions
- CloudWatch Logs configuration
- API key for authentication

### Deployment Commands
```bash
# Build Lambda package
sam build

# Deploy with guided prompts (first time)
sam deploy --guided

# Subsequent deployments
sam deploy

# Local testing
sam local invoke -e test_event.json

# Local API Gateway simulation
sam local start-api
```

---

## 8. Critical Files to Create

### Backend
1. [backend/handler.py](backend/handler.py) - Lambda entry point
2. [backend/template.yaml](backend/template.yaml) - SAM infrastructure template
3. [backend/rag_pipeline.py](backend/rag_pipeline.py) - RAG helper functions
4. [backend/samconfig.toml](backend/samconfig.toml) - SAM deployment config

### Frontend
5. [frontend/src/app/api/upload/route.ts](frontend/src/app/api/upload/route.ts) - Pre-signed URL generation
6. [frontend/src/app/api/roast/route.ts](frontend/src/app/api/roast/route.ts) - Lambda proxy
7. [frontend/.env.local](frontend/.env.local) - Environment variables
8. [frontend/package.json](frontend/package.json) - Dependencies (add AWS SDK)

---

## 9. Implementation Sequence

### Phase 1: AWS Infrastructure Setup
1. Create S3 bucket: `resume-roaster-uploads-{account-id}` in `us-east-1`
2. Configure S3 CORS (allow Vercel + localhost origins)
3. Create IAM user for Next.js with `s3:PutObject` permission
4. Enable Bedrock model access (Claude 3.5 Sonnet + Titan Embeddings) in AWS Console

### Phase 2: Backend Lambda Development
1. Create `backend/template.yaml` (SAM infrastructure)
2. Create `backend/rag_pipeline.py` (modular RAG functions)
3. Create `backend/handler.py` (Lambda orchestration)
4. Deploy: `sam build && sam deploy --guided`
5. Test locally: `sam local invoke -e test_event.json`

### Phase 3: Frontend Next.js Setup
1. Initialize: `npx create-next-app@latest frontend --typescript --tailwind --app`
2. Install AWS SDK: `npm install @aws-sdk/client-s3 @aws-sdk/s3-request-presigner uuid`
3. Create `.env.local` with AWS credentials
4. Create API routes: `upload/route.ts`, `roast/route.ts`
5. Build upload UI component

### Phase 4: Integration Testing
1. Test pre-signed URL generation
2. Test S3 upload from browser
3. Test Lambda invocation via roast API
4. End-to-end flow with sample resume PDF
5. Verify roast quality

### Phase 5: Vercel Deployment
1. Push to GitHub
2. Import to Vercel
3. Configure environment variables
4. Update S3 CORS with Vercel URL
5. Test production deployment

### Phase 6: Optimization & Monitoring
1. CloudWatch structured logging
2. Monitor cold starts and memory usage
3. Optimize chunking strategy
4. Fine-tune roasting prompt
5. Error handling and UX improvements

---

## 10. Cost Estimate (V1)

**Per roast (~$0.01):**
- Lambda compute (3008 MB, 60s): ~$0.002
- Bedrock Claude 3.5 Sonnet (2K input + 1K output): ~$0.009
- Bedrock Titan Embeddings (15 chunks × 500 tokens): ~$0.0001
- S3 storage (10 MB, 30 days): ~$0.0003
- API Gateway: ~$0.000004

---

## 11. Current Status

### Completed ✅
- `/backend/requirements.txt` - Python dependencies defined
- Architecture plan finalized with Gen Z tone and UI specifications
- **Phase 1 Implementation Complete:**
  - [AWS_SETUP_GUIDE.md](AWS_SETUP_GUIDE.md) - Comprehensive AWS setup documentation
  - [scripts/setup-aws-phase1.sh](scripts/setup-aws-phase1.sh) - Bash automation script
  - [scripts/setup-aws-phase1.ps1](scripts/setup-aws-phase1.ps1) - PowerShell automation script
  - [QUICK_START.md](QUICK_START.md) - User-friendly quick start guide

### Ready for User Action 🚀
**You can now run Phase 1 setup:**

**On Windows:**
```powershell
.\scripts\setup-aws-phase1.ps1
```

**On Mac/Linux:**
```bash
chmod +x scripts/setup-aws-phase1.sh
./scripts/setup-aws-phase1.sh
```

**Don't forget:** After running the script, manually enable Bedrock models in AWS Console:
https://console.aws.amazon.com/bedrock/home?region=us-east-1#/modelaccess

### Next Tasks 📋
- **Phase 2:** Backend Lambda Development (SAM template, handler, RAG pipeline)
- **Phase 3:** Frontend Next.js Setup (API routes, UI, Gen Z styling)
