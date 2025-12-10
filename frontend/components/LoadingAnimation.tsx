'use client';

import { useState, useEffect } from 'react';

const loadingMessages = [
  "cooking...",
  "looking pretty mid ngl",
  "this resume is giving...",
  "analyzing the vibes",
  "checking if it's bussin",
  "bro is cooked fr",
  "reading between the lies",
  "no cap, this is taking a sec",
];

export default function LoadingAnimation() {
  const [messageIndex, setMessageIndex] = useState(0);
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
    const interval = setInterval(() => {
      setMessageIndex((prev) => (prev + 1) % loadingMessages.length);
    }, 4000); // Change message every 3 seconds

    return () => clearInterval(interval);
  }, []);

  // Prevent hydration mismatch by not rendering dynamic content on server
  if (!mounted) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[400px] space-y-6">
        <div className="text-9xl animate-float">
          🔥
        </div>
        <div className="h-12 flex items-center justify-center">
          <p className="text-2xl font-semibold text-gray-600 text-shimmer">
            cooking...
          </p>
        </div>
        {/* Circular gradient loading spinner */}
        <div className="spinner-gradient"></div>
      </div>
    );
  }

  return (
    <div className="flex flex-col items-center justify-center min-h-[400px] space-y-6">
      {/* Fire emoji with float animation */}
      <div className="text-9xl animate-float">
        🔥
      </div>

      {/* Rotating loading messages */}
      <div className="h-12 flex items-center justify-center">
        <p className="text-2xl font-semibold text-gray-600 text-shimmer">
          {loadingMessages[messageIndex]}
        </p>
      </div>

      {/* Circular gradient loading spinner */}
      <div className="spinner-gradient"></div>
    </div>
  );
}
