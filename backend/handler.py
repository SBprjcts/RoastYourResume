"""
AWS Lambda Handler for Resume Roaster
Orchestrates the RAG pipeline for resume processing
"""

import json
import boto3
import time
import os
from typing import Dict, Any
from rag_pipeline import (
    load_pdf,
    chunk_text,
    initialize_vectorstore,
    retrieve_context,
    generate_roast,
    extract_full_text
)


# Initialize S3 client
s3_client = boto3.client('s3', region_name='us-east-1')


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda entry point for resume roasting

    API Gateway Proxy Event Structure:
    {
        "body": "{\"s3_bucket\": \"...\", \"s3_key\": \"...\", \"request_id\": \"...\"}",
        "headers": {...},
        "requestContext": {...}
    }

    Returns:
    {
        "statusCode": 200,
        "headers": {...},
        "body": "{\"request_id\": \"...\", \"roast\": \"...\", \"metadata\": {...}}"
    }
    """
    start_time = time.time()

    try:
        # Parse request body
        print("[HANDLER] Parsing request body...")
        body = json.loads(event.get('body', '{}'))
        s3_bucket = body.get('s3_bucket')
        s3_key = body.get('s3_key')
        request_id = body.get('request_id')

        # Validate required fields
        if not all([s3_bucket, s3_key, request_id]):
            return error_response(
                400,
                "Missing required fields: s3_bucket, s3_key, request_id"
            )

        print(f"[HANDLER] Processing request {request_id}")
        print(f"[HANDLER] S3 location: s3://{s3_bucket}/{s3_key}")

        # Step 1: Download PDF from S3 to /tmp/
        pdf_path = f"/tmp/{request_id}.pdf"
        print(f"[HANDLER] Downloading PDF to {pdf_path}...")

        try:
            s3_client.download_file(s3_bucket, s3_key, pdf_path)
            file_size = os.path.getsize(pdf_path)
            print(f"[HANDLER] Downloaded {file_size} bytes")
        except Exception as e:
            return error_response(
                500,
                f"Failed to download PDF from S3: {str(e)}"
            )

        # Step 2: Load PDF
        print("[HANDLER] Loading PDF...")
        documents = load_pdf(pdf_path)

        if not documents:
            return error_response(
                400,
                "PDF appears to be empty or unreadable"
            )

        # Step 3: Extract full text for context
        full_text = extract_full_text(documents)

        # Step 4: Chunk text
        print("[HANDLER] Chunking text...")
        chunks = chunk_text(documents)

        # Step 5: Initialize vector store with embeddings
        print("[HANDLER] Initializing vector store...")
        vectorstore = initialize_vectorstore(chunks, request_id)

        # Step 6: Retrieve relevant context
        # Use multiple queries to get diverse context
        queries = [
            "work experience and accomplishments",
            "skills and qualifications",
            "formatting and presentation issues"
        ]

        all_context_docs = []
        for query in queries:
            context_docs = retrieve_context(vectorstore, query, k=3)
            all_context_docs.extend(context_docs)

        # Deduplicate and format context
        context_text = "\n\n".join([
            f"Section {i+1}:\n{doc.page_content}"
            for i, doc in enumerate(all_context_docs[:5])
        ])

        # Step 7: Generate roast with Claude
        print("[HANDLER] Generating roast...")
        roast = generate_roast(context_text, full_text)

        # Calculate processing time
        processing_time_ms = int((time.time() - start_time) * 1000)

        # Cleanup: Remove PDF file (FAISS is in-memory, no cleanup needed)
        try:
            if os.path.exists(pdf_path):
                os.remove(pdf_path)
            print("[HANDLER] Cleaned up temporary files")
        except Exception as e:
            print(f"[HANDLER] Warning: Cleanup failed: {str(e)}")

        # Return success response
        return success_response(
            request_id=request_id,
            roast=roast,
            metadata={
                "chunks_processed": len(chunks),
                "pages_processed": len(documents),
                "processing_time_ms": processing_time_ms,
                "model_used": "claude-3-5-sonnet-v2",
                "embedding_model": "titan-embed-text-v1"
            }
        )

    except json.JSONDecodeError:
        return error_response(400, "Invalid JSON in request body")

    except Exception as e:
        print(f"[HANDLER] Unexpected error: {str(e)}")
        import traceback
        traceback.print_exc()

        return error_response(
            500,
            f"Internal server error: {str(e)}"
        )


def success_response(request_id: str, roast: str, metadata: Dict[str, Any]) -> Dict[str, Any]:
    """
    Format successful response

    Args:
        request_id: Request ID
        roast: Generated roast text
        metadata: Processing metadata

    Returns:
        API Gateway proxy response
    """
    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Content-Type,X-Api-Key",
            "Access-Control-Allow-Methods": "POST,OPTIONS"
        },
        "body": json.dumps({
            "request_id": request_id,
            "roast": roast,
            "metadata": metadata
        })
    }


def error_response(status_code: int, message: str) -> Dict[str, Any]:
    """
    Format error response

    Args:
        status_code: HTTP status code
        message: Error message

    Returns:
        API Gateway proxy response
    """
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Content-Type,X-Api-Key",
            "Access-Control-Allow-Methods": "POST,OPTIONS"
        },
        "body": json.dumps({
            "error": message
        })
    }
