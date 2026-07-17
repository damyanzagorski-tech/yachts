import Link from 'next/link';
import { buildAlternates } from '@/lib/seo';

export async function generateMetadata() {
  return { alternates: await buildAlternates('/') };
}

export default function Home() {
  return (
    <div className="flex flex-col flex-1 items-center justify-center bg-zinc-50 font-sans dark:bg-black">
      <main className="flex flex-1 w-full max-w-3xl flex-col items-center justify-center gap-8 py-32 px-16 text-center">
        <h1 className="text-3xl font-semibold tracking-tight text-black dark:text-zinc-50">
          Electric Yacht Market
        </h1>
        <p className="max-w-md text-lg text-zinc-600 dark:text-zinc-400">
          The database of electric and hybrid-electric yacht manufacturers and models.
        </p>
        <div className="flex gap-4">
          <Link
            href="/manufacturers"
            className="rounded-full bg-foreground px-5 py-3 text-background hover:bg-[#383838] dark:hover:bg-[#ccc]"
          >
            Manufacturers
          </Link>
          <Link
            href="/models"
            className="rounded-full border border-black/[.08] px-5 py-3 hover:bg-black/[.04] dark:border-white/[.145] dark:hover:bg-[#1a1a1a]"
          >
            Models
          </Link>
        </div>
      </main>
    </div>
  );
}
