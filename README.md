# Resume Roaster 🔥

**Live at: [amicooked.ca](https://amicooked.ca)**

Get your resume roasted with AI-powered, brutally honest feedback. Upload your resume, get roasted with Gen Z humor, and receive actionable tips to improve.

---

## Overview

Resume Roaster is a full-stack serverless application that uses AI to critique resumes with personality. Built with AWS Bedrock (Claude 3.5 Sonnet), Next.js 15, and a RAG (Retrieval-Augmented Generation) pipeline, it provides contextually-aware feedback on your resume in a fun, engaging way.

### Key Features

- **AI-Powered Roasting**: Claude 3.5 Sonnet delivers witty, Gen Z-style critiques
- **RAG Pipeline**: Chunks and embeds your resume for context-aware analysis
- **Serverless Architecture**: Fully serverless with AWS Lambda and S3
- **Modern UI**: Clean, responsive Next.js frontend with Tailwind CSS
- **Secure Uploads**: Pre-signed S3 URLs for direct browser-to-cloud uploads
- **Fast Processing**: Optimized chunking and embedding for sub-30s responses

---

## Tech Stack

### Frontend
- **Framework**: Next.js 15 (React 19, App Router, TypeScript)
- **Styling**: Tailwind CSS with custom animations
- **Hosting**: Vercel
- **File Uploads**: AWS SDK v3 (S3 pre-signed URLs)

### Backend
- **Runtime**: Python 3.11 on AWS Lambda
- **AI/ML**:
  - **LLM**: AWS Bedrock - Claude 3.5 Sonnet v2 (`anthropic.claude-3-5-sonnet-20241022-v2:0`)
  - **Embeddings**: AWS Bedrock - Titan Embeddings (`amazon.titan-embed-text-v1`)
- **RAG Framework**: LangChain (Python)
- **Vector Store**: FAISS (ephemeral, in-memory)
- **PDF Processing**: PyPDFLoader from LangChain Community
- **Infrastructure**: AWS SAM (Serverless Application Model)

### AWS Services
- **Lambda**: Serverless compute (3008 MB, 60s timeout)
- **API Gateway**: REST API with API key authentication
- **S3**: Resume PDF storage with pre-signed URLs
- **Bedrock**: Claude 3.5 Sonnet + Titan Embeddings
- **CloudWatch**: Logging and monitoring

---

## Cost Breakdown

### Per Resume Roast (~$0.011)
- Lambda (60s, 3008MB): ~$0.002
- Claude 3.5 Sonnet (2K input + 1K output): ~$0.009
- Titan Embeddings (15 chunks × 500 tokens): ~$0.0001
- S3 storage (10MB/month): ~$0.0003
- API Gateway: ~$0.000004

### Monthly Estimates
- **100 roasts**: ~$1.10
- **1,000 roasts**: ~$11.00
- **10,000 roasts**: ~$110.00

---

## Local Development

### Prerequisites
- Node.js 18+ and npm
- Python 3.11+
- AWS CLI configured
- AWS SAM CLI installed
- AWS account with Bedrock model access

### Frontend Setup

```bash
cd frontend
npm install
cp .env.example .env.local
# Add your AWS credentials to .env.local
npm run dev
```

Visit `http://localhost:3000`

### Backend Setup

```bash
cd backend
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt

# Deploy to AWS
sam build
sam deploy --guided
```

### Environment Variables

**Frontend (.env.local)**:
```env
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
S3_BUCKET_NAME=resume-roaster-uploads-{account-id}
LAMBDA_API_GATEWAY_URL=https://{api-id}.execute-api.us-east-1.amazonaws.com/prod
API_GATEWAY_KEY=your_api_key
```

**Vercel (Production)**:
Add the same variables in Vercel Dashboard → Settings → Environment Variables

---

## Deployment

### Frontend (Vercel)
1. Push to GitHub
2. Import repository to Vercel
3. Add environment variables
4. Deploy automatically on push to `main`

### Backend (AWS SAM)
```bash
cd backend
sam build
sam deploy
```

Get API Gateway URL and key:
```bash
sam list stack-outputs --stack-name resume-roaster-backend
aws apigateway get-api-keys --region us-east-1 --include-values
```

### S3 CORS Configuration

Update your S3 bucket CORS policy:
```json
[
    {
        "AllowedHeaders": ["*"],
        "AllowedMethods": ["GET", "PUT", "POST", "HEAD"],
        "AllowedOrigins": [
            "http://localhost:3000",
            "https://amicooked-pi.vercel.app",
            "https://amicooked.ca"
        ],
        "ExposeHeaders": ["ETag"],
        "MaxAgeSeconds": 3000
    }
]
```

---

## Project Structure

```
RoastYourResume/
├── frontend/                 # Next.js application
│   ├── app/
│   │   ├── page.tsx         # Main upload/roast UI
│   │   ├── globals.css      # Global styles + animations
│   │   ├── layout.tsx       # Root layout
│   │   └── api/
│   │       ├── upload/      # Pre-signed URL generation
│   │       └── roast/       # Lambda proxy endpoint
│   ├── components/
│   │   ├── LoadingAnimation.tsx
│   │   ├── RoastDisplay.tsx
│   │   ├── TransitionScreen.tsx
│   │   └── Footer.tsx
│   └── public/
│       └── background-pattern.png
│
├── backend/                  # Python Lambda + SAM
│   ├── handler.py           # Lambda entry point
│   ├── rag_pipeline.py      # RAG helper functions
│   ├── template.yaml        # SAM infrastructure
│   ├── requirements.txt     # Python dependencies
│   └── samconfig.toml       # SAM deployment config
│
└── README.md                # This file
```

---

## Key Implementation Details

### RAG Pipeline Optimization

**Chunking Strategy** ([rag_pipeline.py:45-50](backend/rag_pipeline.py#L45-L50)):
- Chunk size: 1500 characters (larger = fewer embeddings = faster)
- Overlap: 150 characters
- Retrieval: Top 3 chunks (reduced from 5 for speed)

**Model Configuration** ([rag_pipeline.py:112-121](backend/rag_pipeline.py#L112-L121)):
```python
llm = ChatBedrock(
    model_id="us.anthropic.claude-3-5-sonnet-20241022-v2:0",
    model_kwargs={
        "max_tokens": 4000,
        "temperature": 0.8,  # Creative roasting
        "top_p": 0.9
    }
)
```

**System Prompt** ([rag_pipeline.py:124-138](backend/rag_pipeline.py#L124-L138)):
- Gen Z tone with slang ("cooked", "fr fr", "no cap", "mid")
- Brutally honest but constructive feedback
- Structured sections: Summary, Experience, Skills, Format
- Actionable tips at the end

### Frontend State Machine

**Upload Flow** ([page.tsx:28-154](frontend/app/page.tsx#L28-L154)):
```
upload → uploading → uploaded → loading → transition → roasted
                                            ↓
                                    (harsh roast detection)
```

**Harsh Roast Detection** ([page.tsx:35-44](frontend/app/page.tsx#L35-L44)):
Triggers transition screen animation if roast contains keywords like "cooked", "mid", "disaster", etc.

---

## Monitoring & Analytics

### AWS CloudWatch
- Lambda logs: `/aws/lambda/resume-roaster-backend-*`
- Metrics: Invocations, Errors, Duration, Throttles
- Custom dashboard: Lambda + API Gateway metrics

### Cost Monitoring
- AWS Cost Explorer: Track daily/monthly Bedrock usage
- AWS Budgets: Set alerts at $50/month

### Vercel Analytics
- Page views and unique visitors
- Geographic distribution
- Performance metrics

**Access**:
- CloudWatch: [AWS Console](https://console.aws.amazon.com/cloudwatch)
- Cost Explorer: [AWS Billing](https://console.aws.amazon.com/cost-management/home)
- Vercel: Dashboard → Analytics

---

## Security

### Frontend
- Environment variables never exposed to client
- Pre-signed URLs expire in 5 minutes
- File type validation (PDF only)
- File size limit (10MB)

### Backend
- IAM role with least-privilege permissions
- API Gateway key authentication
- S3 CORS limited to specific origins
- Lambda execution role scoped to specific resources

### Production Checklist
- ✅ `.env` files in `.gitignore`
- ✅ Vercel environment variables marked as sensitive
- ✅ S3 bucket not publicly accessible
- ✅ API Gateway throttling enabled (20 req/s, 50 burst)

---

## Performance

### Optimization Techniques
- **Larger chunks**: 1500 chars → fewer embeddings
- **Fewer retrievals**: Top 3 chunks instead of 5
- **Cross-region inference**: Bedrock routing for availability
- **FAISS**: In-memory vector store (faster than ChromaDB)
- **Vercel Edge**: Global CDN for frontend

### Typical Response Times
- Upload to S3: 1-2 seconds
- Lambda cold start: 3-5 seconds
- Lambda warm: 15-25 seconds (PDF processing + embeddings + LLM)
- Total: 20-30 seconds end-to-end

---

## Troubleshooting

### Common Issues

**CORS Errors**:
- Verify S3 bucket CORS includes your domain
- Check browser console for specific origin

**403 Forbidden**:
- Verify Vercel environment variables are set
- Check API Gateway key is correct

**Lambda 500 Error**:
- Check CloudWatch logs for specific error
- Verify IAM permissions for Bedrock and S3

**504 Gateway Timeout**:
- Lambda exceeded 29s API Gateway limit
- Check CloudWatch for processing time
- Reduce chunk size or retrieval count

---

## Future Enhancements

- [ ] Resume version comparison
- [ ] Export roast as PDF
- [ ] User accounts and history
- [ ] LinkedIn profile analysis
- [ ] A/B testing different roasting styles
- [ ] Multi-language support
- [ ] Resume templates and suggestions
- [ ] Real-time streaming responses

---

## Contributing

This is a personal project, but feedback and suggestions are welcome! Feel free to open issues or reach out.

---

## License

MIT License - Feel free to use this for learning or your own projects.

---

## Credits

Built with:
- [Next.js](https://nextjs.org/) - React framework
- [AWS Bedrock](https://aws.amazon.com/bedrock/) - Claude AI
- [LangChain](https://www.langchain.com/) - RAG framework
- [FAISS](https://github.com/facebookresearch/faiss) - Vector search
- [Vercel](https://vercel.com/) - Frontend hosting
- [Tailwind CSS](https://tailwindcss.com/) - Styling

---

**Questions?** Check the [CLAUDE.md](CLAUDE.md) file for detailed implementation notes.
