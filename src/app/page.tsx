import Link from 'next/link';
import { buildAlternates } from '@/lib/seo';

export async function generateMetadata() {
  return { alternates: await buildAlternates('/') };
}

export default function Home() {
  return (
    <div className="flex flex-1 flex-col items-center justify-center bg-background">
      <main className="flex w-full max-w-3xl flex-1 flex-col items-center justify-center gap-8 px-16 py-32 text-center">
        <span className="marker">The database</span>
        <h1 className="font-serif text-4xl font-light tracking-tight sm:text-5xl">
          Electric <em className="text-copper">Yacht</em> Market
        </h1>
        <p className="max-w-md text-lg text-ink-soft">
          Electric and hybrid-electric yacht manufacturers and models, tracked and compared.
        </p>
        <div className="flex gap-4">
          <Link
            href="/manufacturers"
            className="rounded-full bg-copper px-6 py-3 text-sm font-semibold uppercase tracking-[0.14em] text-paper transition-colors hover:bg-copper-soft"
          >
            Manufacturers
          </Link>
          <Link
            href="/models"
            className="rounded-full border border-rule-strong px-6 py-3 text-sm font-semibold uppercase tracking-[0.14em] transition-colors hover:border-copper hover:text-copper"
          >
            Models
          </Link>
        </div>
      </main>
    </div>
  );
}
