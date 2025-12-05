import { NextRequest, NextResponse } from 'next/server';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { v4 as uuidv4 } from 'uuid';

const s3Client = new S3Client({
  region: process.env.AWS_REGION || 'us-east-1',
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID || '',
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || '',
  },
});

export async function POST(request: NextRequest) {
  try {
    const { fileName, fileType } = await request.json();

    // Validate file type (PDF only)
    if (!fileType || fileType !== 'application/pdf') {
      return NextResponse.json(
        { error: 'Only PDF files are allowed' },
        { status: 400 }
      );
    }

    // Generate unique request ID
    const requestId = uuidv4();

    // Sanitize filename (remove special chars, keep alphanumeric and dots)
    const sanitizedFileName = fileName.replace(/[^a-zA-Z0-9.-]/g, '_');

    // S3 key: uploads/{requestId}/{filename}
    const s3Key = `uploads/${requestId}/${sanitizedFileName}`;
    const s3Bucket = process.env.S3_BUCKET_NAME || '';

    // Generate pre-signed URL (5 min expiration)
    const command = new PutObjectCommand({
      Bucket: s3Bucket,
      Key: s3Key,
      ContentType: fileType,
    });

    const presignedUrl = await getSignedUrl(s3Client, command, {
      expiresIn: 300, // 5 minutes
    });

    return NextResponse.json({
      presignedUrl,
      s3Bucket,
      s3Key,
      requestId,
    });

  } catch (error) {
    console.error('Error generating pre-signed URL:', error);
    return NextResponse.json(
      { error: 'Failed to generate upload URL' },
      { status: 500 }
    );
  }
}
