'use client';

import { useEffect } from 'react';
import Image from 'next/image';

interface TransitionScreenProps {
  onTransitionComplete: () => void;
}

export default function TransitionScreen({ onTransitionComplete }: TransitionScreenProps) {
  useEffect(() => {
    const timer = setTimeout(() => {
      onTransitionComplete();
    }, 2500);

    return () => clearTimeout(timer);
  }, [onTransitionComplete]);

  return (
    <div className="flex flex-col items-center justify-center min-h-[400px] space-y-6 animate-fade-in">
      <div className="relative w-64 h-64">
        <Image
          src="/images/speedmeme.gif"
          alt="Speed meme"
          fill
          className="object-contain"
          priority
          unoptimized
        />
      </div>
      <p className="text-3xl font-bold text-gray-800">
        Yikes...
      </p>
      <p className="text-lg text-gray-600">
        This is gonna hurt
      </p>
    </div>
  );
}
