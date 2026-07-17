import Link from 'next/link';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { buildAlternates } from '@/lib/seo';
import type { Manufacturer } from '@/lib/supabase/types';

export async function generateMetadata() {
  return {
    title: 'Electric Yacht Manufacturers',
    alternates: await buildAlternates('/manufacturers'),
  };
}

async function getManufacturers(): Promise<{ data: Manufacturer[]; error: string | null }> {
  try {
    const supabase = createSupabaseServerClient();
    const { data, error } = await supabase
      .from('manufacturers')
      .select('*')
      .order('name');

    if (error) return { data: [], error: error.message };
    return { data: data ?? [], error: null };
  } catch (err) {
    return { data: [], error: err instanceof Error ? err.message : 'Unknown error' };
  }
}

export default async function ManufacturersPage() {
  const { data: manufacturers, error } = await getManufacturers();
  const electricOnly = manufacturers.filter((m) => m.product_line === 'electric_only').length;

  return (
    <main className="mx-auto max-w-5xl px-6 py-16">
      <div className="grid gap-8 border-b border-rule pb-12 md:grid-cols-[1fr_1.3fr] md:items-end md:gap-16">
        <div>
          <span className="marker">Builders</span>
          <h1 className="mt-3 font-serif text-4xl font-light tracking-tight md:text-5xl">Manufacturers</h1>
        </div>
        <div className="flex gap-10 md:justify-end">
          <div>
            <div className="font-serif text-4xl font-light italic text-copper">{manufacturers.length}</div>
            <div className="mt-1 text-xs font-semibold uppercase tracking-[0.2em] text-muted">Total builders</div>
          </div>
          <div>
            <div className="font-serif text-4xl font-light italic text-copper">{electricOnly}</div>
            <div className="mt-1 text-xs font-semibold uppercase tracking-[0.2em] text-muted">Electric only</div>
          </div>
        </div>
      </div>

      <div className="mt-10">
      {error && (
        <p className="rounded-md border border-copper-soft bg-ink-2 p-4 text-sm text-paper">
          Couldn&apos;t load manufacturers: {error}. Have you set up{' '}
          <code>.env.local</code> with your Supabase credentials?
        </p>
      )}

      {!error && manufacturers.length === 0 && <p className="text-muted">No manufacturers found.</p>}

      <ul className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        {manufacturers.map((m) => (
          <li
            key={m.id}
            className="rounded-lg border border-rule bg-ink-2 p-5 transition-colors hover:border-copper"
          >
            <Link href={`/manufacturers/${m.slug}`} className="font-serif text-lg hover:text-copper">
              {m.name}
            </Link>
            <p className="mt-2 text-xs font-semibold uppercase tracking-[0.16em] text-muted">
              {m.country ?? 'Unknown country'} ·{' '}
              {m.product_line === 'electric_only' ? 'Electric only' : 'Mixed'}
            </p>
          </li>
        ))}
      </ul>
      </div>
    </main>
  );
}
