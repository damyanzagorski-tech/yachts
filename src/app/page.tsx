import Link from 'next/link';
import { buildAlternates } from '@/lib/seo';

export async function generateMetadata() {
  return { alternates: await buildAlternates('/') };
}

export default function Home() {
  return (
    <main className="hero-depth -mt-16 flex flex-1 items-center pt-16">
      <div className="mx-auto grid w-full max-w-6xl gap-12 px-6 py-24 sm:px-10 md:grid-cols-[1.5fr_1fr] md:items-end md:gap-20">
        <div>
          <span className="marker">The database</span>
          <h1 className="mt-6 font-serif text-6xl font-light leading-[0.95] tracking-tight sm:text-7xl md:text-8xl">
            Electric
            <br />
            <em className="text-copper">Yacht</em>
            <br />
            Market
          </h1>
        </div>

        <div className="flex flex-col gap-8 md:pb-2">
          <p className="max-w-xs font-serif text-xl font-light italic text-muted">
            Electric and hybrid-electric yacht manufacturers and models, tracked and compared.
          </p>
          <div className="flex flex-wrap gap-4">
            <Link
              href="/manufacturers"
              className="rounded-full bg-copper px-6 py-3 text-xs font-semibold uppercase tracking-[0.18em] text-paper transition-colors hover:bg-copper-soft"
            >
              Manufacturers
            </Link>
            <Link
              href="/models"
              className="rounded-full border border-rule-strong px-6 py-3 text-xs font-semibold uppercase tracking-[0.18em] transition-colors hover:border-copper hover:text-copper"
            >
              Models
            </Link>
          </div>
        </div>
      </div>
    </main>
  );
}
