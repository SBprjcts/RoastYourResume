'use client';

import { useState, useRef } from 'react';
import LoadingAnimation from '@/components/LoadingAnimation';
import RoastDisplay from '@/components/RoastDisplay';
import TransitionScreen from '@/components/TransitionScreen';
import Footer from '@/components/Footer';

type AppState = 'upload' | 'uploading' | 'uploaded' | 'loading' | 'transition' | 'roasted';

interface UploadData {
  s3Bucket: string;
  s3Key: string;
  requestId: string;
  fileName: string;
}

interface RoastData {
  roast: string;
  metadata?: {
    chunks_processed?: number;
    pages_processed?: number;
    processing_time_ms?: number;
    model_used?: string;
  };
}

export default function Home() {
  const [state, setState] = useState<AppState>('upload');
  const [uploadData, setUploadData] = useState<UploadData | null>(null);
  const [roastData, setRoastData] = useState<RoastData | null>(null);
  const [error, setError] = useState<string>('');
  const fileInputRef = useRef<HTMLInputElement>(null);

  const detectHarshRoast = (roastText: string): boolean => {
    const HARSH_KEYWORDS = [
      'mid', 'cooked', 'fr fr', 'no cap', 'bussin', 'giving',
      'ngl', 'yikes', 'oof', 'brutal', 'harsh', 'disaster',
      'terrible', 'awful', 'weak', 'lacking', 'missing', 'bro is'
    ];

    const lowerText = roastText.toLowerCase();
    return HARSH_KEYWORDS.some(keyword => lowerText.includes(keyword));
  };

  const handleFileSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    // Validate file type
    if (file.type !== 'application/pdf') {
      setError('Only PDF files are allowed');
      return;
    }

    // Validate file size (10MB max)
    if (file.size > 10 * 1024 * 1024) {
      setError('File size must be less than 10MB');
      return;
    }

    setError('');
    setState('uploading'); // Show loading spinner while uploading

    try {
      // Step 1: Get pre-signed URL
      const uploadResponse = await fetch('/api/upload', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          fileName: file.name,
          fileType: file.type,
        }),
      });

      if (!uploadResponse.ok) {
        throw new Error('Failed to get upload URL');
      }

      const { presignedUrl, s3Bucket, s3Key, requestId } = await uploadResponse.json();

      // Step 2: Upload to S3
      const s3Response = await fetch(presignedUrl, {
        method: 'PUT',
        body: file,
        headers: {
          'Content-Type': file.type,
        },
      });

      if (!s3Response.ok) {
        throw new Error('Failed to upload file to S3');
      }

      // Success! Save upload data and show "Roast" button
      setUploadData({
        s3Bucket,
        s3Key,
        requestId,
        fileName: file.name,
      });
      setState('uploaded');

    } catch (err) {
      console.error('Upload error:', err);
      setError('Failed to upload file. Please try again.');
      setState('upload'); // Go back to upload state on error
    }
  };

  const handleRoast = async () => {
    if (!uploadData) return;

    setState('loading');
    setError('');

    try {
      const roastResponse = await fetch('/api/roast', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          s3Bucket: uploadData.s3Bucket,
          s3Key: uploadData.s3Key,
          requestId: uploadData.requestId,
        }),
      });

      if (!roastResponse.ok) {
        // Show simple error message for timeouts
        if (roastResponse.status === 504) {
          throw new Error('Error, please try again');
        }
        const errorData = await roastResponse.json();
        throw new Error(errorData.error || 'Error, please try again');
      }

      const data = await roastResponse.json();

      setRoastData({
        roast: data.roast,
        metadata: data.metadata,
      });

      // Check if roast is harsh and show transition if needed
      const isHarsh = detectHarshRoast(data.roast);

      if (isHarsh) {
        setState('transition');
      } else {
        setState('roasted');
      }

    } catch (err: any) {
      console.error('Roast error:', err);
      setError(err.message || 'Failed to roast resume. Please try again.');
      setState('uploaded'); // Go back to uploaded state
    }
  };

  const handleReset = () => {
    setState('upload');
    setUploadData(null);
    setRoastData(null);
    setError('');
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  };

  return (
    <>
      {/* Header */}
      <header className="bg-roast-yellow py-8 mb-12">
        <div className="text-center">
          <h1 className="text-6xl font-bold text-gray-900 mb-4">
            Resume Roaster 🔥
          </h1>
          <p className="text-xl text-gray-800">
            Find out if you're cooked in this job market.
          </p>
        </div>
      </header>

      <main className="min-h-screen px-4 pb-24">
        <div className="max-w-4xl mx-auto">
        {/* Main Content */}
        {state === 'upload' && (
          <div className="bg-white rounded-2xl shadow-xl p-12 border-4 border-roast-yellow">
            <div className="text-center space-y-6">
              <div className="text-8xl">
                📄
              </div>
              <h2 className="text-3xl font-bold text-gray-900">
                Upload Your Resume
              </h2>
              <p className="text-gray-600">
                PDF only, 10MB max. I'll keep it real with the feedback.
              </p>

              <label className="inline-block">
                <input
                  ref={fileInputRef}
                  type="file"
                  accept="application/pdf"
                  onChange={handleFileSelect}
                  className="hidden"
                />
                <span className="px-8 py-4 bg-roast-yellow text-gray-900 font-bold text-lg rounded-lg hover:bg-yellow-300 transition-colors cursor-pointer shadow-lg inline-block">
                  Choose PDF File
                </span>
              </label>

              {error && (
                <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded">
                  {error}
                </div>
              )}
            </div>
          </div>
        )}

        {state === 'uploading' && (
          <div className="bg-white rounded-2xl shadow-xl p-12 border-4 border-roast-yellow">
            <div className="flex flex-col items-center justify-center min-h-[400px]">
              {/* Just the circular spinner, centered - no emoji, no text */}
              <div className="spinner-gradient"></div>
            </div>
          </div>
        )}

        {state === 'uploaded' && uploadData && (
          <div className="bg-white rounded-2xl shadow-xl p-12 border-4 border-roast-yellow">
            <div className="text-center space-y-6">
              <div className="text-8xl">
                ✅
              </div>
              <h2 className="text-3xl font-bold text-gray-900">
                Resume Uploaded!
              </h2>
              <p className="text-gray-700 text-lg">
                <span className="font-semibold">{uploadData.fileName}</span>
              </p>
              <p className="text-gray-600">
                Think you can handle it? Click below to find out how cooked you are.
              </p>

              <div className="flex flex-col sm:flex-row gap-4 justify-center pt-4">
                <button
                  onClick={handleRoast}
                  className="px-10 py-4 bg-roast-yellow text-gray-900 font-bold text-xl rounded-lg hover:bg-yellow-300 transition-colors shadow-lg"
                >
                  Cook Resume 🔥
                </button>
                <button
                  onClick={handleReset}
                  className="px-8 py-4 bg-gray-200 text-gray-700 font-semibold text-lg rounded-lg hover:bg-gray-300 transition-colors"
                >
                  Upload Different File
                </button>
              </div>

              {error && (
                <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mt-4">
                  {error}
                </div>
              )}
            </div>
          </div>
        )}

        {state === 'loading' && (
          <div className="bg-white rounded-2xl shadow-xl p-12 border-4 border-roast-yellow">
            <LoadingAnimation />
          </div>
        )}

        {state === 'transition' && (
          <div className="bg-white rounded-2xl shadow-xl p-12 border-4 border-roast-yellow">
            <TransitionScreen
              onTransitionComplete={() => setState('roasted')}
            />
          </div>
        )}

        {state === 'roasted' && roastData && (
          <RoastDisplay
            roast={roastData.roast}
            metadata={roastData.metadata}
            onReset={handleReset}
          />
        )}
        </div>
      </main>
      <Footer />
    </>
  );
}
