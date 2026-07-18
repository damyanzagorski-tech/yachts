import type { Metadata } from "next";
import { Fraunces, Manrope } from "next/font/google";
import { SiteNav } from "@/components/SiteNav";
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
        <SiteNav />
        <div className="flex flex-1 flex-col pt-16">{children}</div>
        <footer className="border-t border-white/[.06] bg-ink px-6 py-14 text-paper">
          <div className="mx-auto flex max-w-6xl flex-wrap items-end justify-between gap-8">
            <div>
              <div className="font-serif text-xl font-light uppercase tracking-[0.28em]">
                Electric <em className="text-copper-soft">Yacht</em> Market
              </div>
              <div className="mt-3 text-[11px] uppercase tracking-[0.18em] text-paper/40">
                The database of electric &amp; hybrid-electric yachts
              </div>
            </div>
            <div className="flex gap-8 text-[11px] uppercase tracking-[0.25em] text-paper/60">
              <span>© 2026 Electric Yacht Market</span>
            </div>
          </div>
        </footer>
      </body>
    </html>
  );
}
