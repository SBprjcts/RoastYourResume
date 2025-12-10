"""
RAG Pipeline for Resume Roasting
Modular helper functions for PDF processing, embeddings, and LLM generation
"""

import boto3
from typing import List
from langchain_core.documents import Document
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_community.document_loaders import PyPDFLoader
from langchain_community.vectorstores import FAISS
from langchain_aws import BedrockEmbeddings, ChatBedrock


# Initialize Bedrock client (reused across functions)
bedrock_runtime = boto3.client('bedrock-runtime', region_name='us-east-1')


def load_pdf(file_path: str) -> List[Document]:
    """
    Load PDF file using PyPDFLoader from LangChain

    Args:
        file_path: Path to PDF file (usually in /tmp/)

    Returns:
        List of Document objects with page content and metadata
    """
    loader = PyPDFLoader(file_path)
    documents = loader.load()
    print(f"[RAG] Loaded {len(documents)} pages from PDF")
    return documents


def chunk_text(documents: List[Document]) -> List[Document]:
    """
    Split documents into chunks using RecursiveCharacterTextSplitter

    Args:
        documents: List of Document objects from PDF loader

    Returns:
        List of chunked Document objects
    """
    text_splitter = RecursiveCharacterTextSplitter(
        chunk_size=2000,  # Even larger chunks = fewer embeddings = faster
        chunk_overlap=100,  # Reduced overlap
        length_function=len,
        separators=["\n\n", "\n", " ", ""]
    )

    chunks = text_splitter.split_documents(documents)
    print(f"[RAG] Created {len(chunks)} chunks from {len(documents)} pages")
    return chunks


def initialize_vectorstore(chunks: List[Document], request_id: str) -> FAISS:
    """
    Initialize FAISS vector store with Bedrock Titan embeddings

    Args:
        chunks: List of chunked Document objects
        request_id: Unique request ID for identification

    Returns:
        FAISS vector store instance
    """
    # Initialize Bedrock Embeddings (Titan)
    embeddings = BedrockEmbeddings(
        client=bedrock_runtime,
        model_id="amazon.titan-embed-text-v1"
    )

    print(f"[RAG] Initializing FAISS vector store for request {request_id}")
    vectorstore = FAISS.from_documents(
        documents=chunks,
        embedding=embeddings
    )

    print(f"[RAG] Embedded {len(chunks)} chunks into FAISS")
    return vectorstore


def retrieve_context(vectorstore: FAISS, query: str, k: int = 2) -> List[Document]:
    """
    Retrieve top-k most relevant chunks via similarity search

    Args:
        vectorstore: FAISS vector store
        query: Search query (e.g., "resume weaknesses")
        k: Number of top results to return

    Returns:
        List of relevant Document objects
    """
    results = vectorstore.similarity_search(query, k=k)
    print(f"[RAG] Retrieved {len(results)} relevant chunks")
    return results


def generate_roast(context: str, resume_text: str) -> str:
    """
    Generate witty resume roast using Claude 3.5 Sonnet with Gen Z tone

    Args:
        context: Retrieved relevant chunks from vector store
        resume_text: Full resume text for reference

    Returns:
        Generated roast as string
    """
    # Initialize Claude 3.5 Sonnet v2 (using cross-region inference profile for on-demand access)
    llm = ChatBedrock(
        client=bedrock_runtime,
        model_id="us.anthropic.claude-3-5-sonnet-20241022-v2:0",
        model_kwargs={
            "max_tokens": 3000,  # Reduced for faster responses
            "temperature": 0.8,  # Creative roasting
            "top_p": 0.9
        }
    )

    # Gen Z roasting system prompt
    system_prompt = """You are a witty Gen Z resume critic who keeps it real. Use Gen Z slang naturally (words like "cooked", "bro is...", "you're cooked", "fr fr", "no cap", "mid", "it's giving...", etc).

CRITICAL CONTEXT: The current year is 2025/2026. When reviewing work experience, anything from 2023-2026 is recent and current. DO NOT refer to 2024 or 2025 as "future" - they are NOW or the recent past. Any content in brackets [] is for your information only and should not be displayed in your response.

Your job is to roast resumes with brutal honesty while providing actionable feedback.
Be sarcastic but constructive. Point out clichés, buzzwords, formatting issues, and weak accomplishments.

Structure your roast in sections (put in subtitles):
1. **Summary (Roast)** - Overall vibe check (2-3 sentences)
2. **Experience Critique** - Call out weak bullets, buzzwords, vague accomplishments
3. **Skills Assessment** - Roast generic skills, missing technical depth
4. **Format & Style** - Comment on layout, length, readability

Keep the vibe casual but insightful - like a brutally honest friend reviewing their homie's resume.
End with 2-3 concrete actionable tips to actually improve the resume."""

    # Construct prompt with context and resume
    user_prompt = f"""Here's a resume that needs your honest roasting:

RESUME CONTENT:
{resume_text[:3000]}

RELEVANT SECTIONS (from vector search):
{context}

Roast this resume with your signature Gen Z style. Be brutally honest but constructive."""

    # Generate roast
    print("[RAG] Generating roast with Claude 3.5 Sonnet...")
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt}
    ]

    response = llm.invoke(messages)
    roast = response.content

    print(f"[RAG] Generated roast ({len(roast)} chars)")
    return roast


def extract_full_text(documents: List[Document]) -> str:
    """
    Extract full text from all document pages

    Args:
        documents: List of Document objects

    Returns:
        Concatenated text from all pages
    """
    full_text = "\n\n".join([doc.page_content for doc in documents])
    return full_text
