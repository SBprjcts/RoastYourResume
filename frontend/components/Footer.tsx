'use client';

interface FooterProps {
  link?: string;
}

export default function Footer({ link }: FooterProps) {
  return (
    <footer className="fixed bottom-0 left-0 right-0 py-4 bg-roast-cream text-center z-10">
      <p className="text-sm text-gray-500">
        {link ? (
          <a
            href={link}
            target="_blank"
            rel="noopener noreferrer"
            className="hover:text-gray-700 transition-colors"
          >
            Powered by Saif Buheis
          </a>
        ) : (
          'Powered by Saif Buheis'
        )}
      </p>
    </footer>
  );
}
