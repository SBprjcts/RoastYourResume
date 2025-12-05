'use client';

interface RoastDisplayProps {
  roast: string;
  metadata?: {
    chunks_processed?: number;
    pages_processed?: number;
    processing_time_ms?: number;
    model_used?: string;
  };
  onReset: () => void;
}

export default function RoastDisplay({ roast, metadata, onReset }: RoastDisplayProps) {
  return (
    <div className="w-full max-w-4xl mx-auto space-y-6">
      {/* Header */}
      <div className="text-center space-y-2">
        <h2 className="text-4xl font-bold text-gray-900">
          Your Roast is Ready ✅
        </h2>
        <p className="text-gray-600">
          Prepared with brutal honesty, no cap
        </p>
      </div>

      {/* Roast Content */}
      <div className="bg-white rounded-2xl shadow-xl p-8 border-4 border-roast-yellow">
        <div className="prose prose-lg max-w-none">
          {roast.split('\n').map((paragraph, index) => {
            // Check if paragraph is a heading (starts with ** or #)
            if (paragraph.trim().startsWith('**') && paragraph.trim().endsWith('**')) {
              const headingText = paragraph.replace(/\*\*/g, '').trim();
              return (
                <h3 key={index} className="text-2xl font-bold text-gray-900 mt-6 mb-3">
                  {headingText}
                </h3>
              );
            } else if (paragraph.trim().startsWith('#')) {
              const headingText = paragraph.replace(/^#+\s*/, '').trim();
              return (
                <h3 key={index} className="text-2xl font-bold text-gray-900 mt-6 mb-3">
                  {headingText}
                </h3>
              );
            } else if (paragraph.trim().length > 0) {
              return (
                <p key={index} className="text-gray-800 leading-relaxed mb-4">
                  {paragraph}
                </p>
              );
            }
            return null;
          })}
        </div>
      </div>

      {/* Metadata */}
      {/* {metadata && (
        <div className="bg-gray-100 rounded-lg p-4 text-sm text-gray-600">
          <p className="font-semibold mb-2">Analysis Details:</p>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {metadata.pages_processed && (
              <div>
                <span className="font-medium">Pages:</span> {metadata.pages_processed}
              </div>
            )}
            {metadata.chunks_processed && (
              <div>
                <span className="font-medium">Sections:</span> {metadata.chunks_processed}
              </div>
            )}
            {metadata.processing_time_ms && (
              <div>
                <span className="font-medium">Time:</span> {(metadata.processing_time_ms / 1000).toFixed(1)}s
              </div>
            )}
            {metadata.model_used && (
              <div>
                <span className="font-medium">Model:</span> Claude 3.5
              </div>
            )}
          </div>
        </div>
      )} */}

      {/* Action Buttons */}
      <div className="flex justify-center space-x-4">
        <button
          onClick={onReset}
          className="px-8 py-3 bg-roast-yellow text-gray-900 font-semibold rounded-lg hover:bg-yellow-300 transition-colors shadow-md"
        >
          Roast Another Resume 🔥
        </button>
        <button
          onClick={() => {
            navigator.clipboard.writeText(roast);
            alert('Roast copied to clipboard!');
          }}
          className="px-8 py-3 bg-gray-200 text-gray-900 font-semibold rounded-lg hover:bg-gray-300 transition-colors shadow-md"
        >
          Copy Roast
        </button>
      </div>
    </div>
  );
}
