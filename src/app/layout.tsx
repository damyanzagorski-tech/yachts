import type { Metadata } from "next";
import Link from "next/link";
import { Fraunces, Manrope } from "next/font/google";
import "./globals.css";

const fraunces = Fraunces({
  variable: "--font-fraunces",
  subsets: ["latin"],
  weight: ["300", "400", "500", "600"],
  style: ["normal", "italic"],
});

const manrope = Manrope({
  variable: "--font-manrope",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
});

export const metadata: Metadata = {
  title: "Electric Yacht Market",
  description: "Electric and hybrid-electric yacht manufacturers and models.",
  // TODO: remove before public launch — blocks all search indexing (see next.config.ts too).
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
      className={`${fraunces.variable} ${manrope.variable} h-full antialiased`}
    >
      <body className="min-h-full flex flex-col">
        <header className="relative z-10">
          <nav className="mx-auto flex max-w-5xl items-center gap-8 px-6 py-5 text-xs font-semibold uppercase tracking-[0.18em]">
            <Link href="/" className="font-serif text-base font-light normal-case tracking-[0.1em]">
              Electric <em className="text-copper">Yacht</em> Market
            </Link>
            <Link href="/manufacturers" className="text-muted transition-colors hover:text-copper">
              Manufacturers
            </Link>
            <Link href="/models" className="text-muted transition-colors hover:text-copper">
              Models
            </Link>
            <Link href="/guides" className="text-muted transition-colors hover:text-copper">
              Guides
            </Link>
          </nav>
        </header>
        <div className="flex flex-1 flex-col">{children}</div>
      </body>
    </html>
  );
}
