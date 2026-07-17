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

  return (
    <main className="mx-auto max-w-5xl px-6 py-16">
      <span className="marker">{manufacturers.length} builders</span>
      <h1 className="mt-3 mb-8 font-serif text-3xl font-light tracking-tight">Manufacturers</h1>

      {error && (
        <p className="rounded-md border border-amber-300 bg-amber-50 p-4 text-sm text-amber-900 dark:border-amber-900 dark:bg-amber-950 dark:text-amber-200">
          Couldn&apos;t load manufacturers: {error}. Have you set up{' '}
          <code>.env.local</code> with your Supabase credentials?
        </p>
      )}

      {!error && manufacturers.length === 0 && <p className="text-ink-soft">No manufacturers found.</p>}

      <ul className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        {manufacturers.map((m) => (
          <li
            key={m.id}
            className="rounded-lg border border-rule p-5 transition-colors hover:border-copper"
          >
            <Link href={`/manufacturers/${m.slug}`} className="font-serif text-lg hover:text-copper">
              {m.name}
            </Link>
            <p className="mt-2 text-xs font-semibold uppercase tracking-[0.16em] text-ink-soft">
              {m.country ?? 'Unknown country'} ·{' '}
              {m.product_line === 'electric_only' ? 'Electric only' : 'Mixed'}
            </p>
          </li>
        ))}
      </ul>
    </main>
  );
}
