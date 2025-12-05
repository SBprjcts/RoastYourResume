import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Resume Roaster 🔥",
  description: "Find out if you're cooked in this job market.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="antialiased">
        {children}
      </body>
    </html>
  );
}
