'use client';

import { useEffect, useRef, useState } from 'react';
import twemoji from 'twemoji';

interface EmojiProps {
  emoji: string;
  className?: string;
}

export default function Emoji({ emoji, className = '' }: EmojiProps) {
  const [parsedEmoji, setParsedEmoji] = useState(emoji);
  const emojiRef = useRef<HTMLSpanElement>(null);

  useEffect(() => {
    // Parse emoji to Twemoji HTML
    const parsed = twemoji.parse(emoji, {
      folder: 'svg',
      ext: '.svg'
    });
    setParsedEmoji(parsed);
  }, [emoji]);

  return (
    <span
      ref={emojiRef}
      className={`inline-block ${className}`}
      dangerouslySetInnerHTML={{ __html: parsedEmoji }}
      suppressHydrationWarning
    />
  );
}
