import type { Metadata } from "next";
import Link from "next/link";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Electric Yacht Market",
  description: "Electric and hybrid-electric yacht manufacturers and models.",
  robots: {
    index: false,
    follow: false,
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="en"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col">
        <header className="border-b border-black/[.08] dark:border-white/[.145]">
          <nav className="mx-auto flex max-w-4xl items-center gap-6 px-6 py-4 text-sm font-medium">
            <Link href="/">Electric Yacht Market</Link>
            <Link href="/manufacturers" className="text-zinc-600 hover:text-inherit dark:text-zinc-400">
              Manufacturers
            </Link>
            <Link href="/models" className="text-zinc-600 hover:text-inherit dark:text-zinc-400">
              Models
            </Link>
            <Link href="/guides" className="text-zinc-600 hover:text-inherit dark:text-zinc-400">
              Guides
            </Link>
          </nav>
        </header>
        <div className="flex flex-1 flex-col">{children}</div>
      </body>
    </html>
  );
}
