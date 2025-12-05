import { NextRequest, NextResponse } from 'next/server';

export async function POST(request: NextRequest) {
  try {
    const { s3Bucket, s3Key, requestId } = await request.json();

    // Validate required fields
    if (!s3Bucket || !s3Key || !requestId) {
      return NextResponse.json(
        { error: 'Missing required fields: s3Bucket, s3Key, requestId' },
        { status: 400 }
      );
    }

    const apiGatewayUrl = process.env.LAMBDA_API_GATEWAY_URL || '';
    const apiKey = process.env.API_GATEWAY_KEY || '';

    if (!apiGatewayUrl || !apiKey) {
      console.error('Missing Lambda API Gateway configuration');
      return NextResponse.json(
        { error: 'Server configuration error' },
        { status: 500 }
      );
    }

    // Call Lambda via API Gateway
    const lambdaResponse = await fetch(`${apiGatewayUrl}/roast`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Api-Key': apiKey,
      },
      body: JSON.stringify({
        s3_bucket: s3Bucket,
        s3_key: s3Key,
        request_id: requestId,
      }),
    });

    if (!lambdaResponse.ok) {
      const errorText = await lambdaResponse.text();
      console.error('Lambda error:', errorText);
      return NextResponse.json(
        { error: `Lambda request failed: ${lambdaResponse.status}` },
        { status: lambdaResponse.status }
      );
    }

    const data = await lambdaResponse.json();

    return NextResponse.json(data);

  } catch (error) {
    console.error('Error calling Lambda:', error);
    return NextResponse.json(
      { error: 'Failed to process roast request' },
      { status: 500 }
    );
  }
}
