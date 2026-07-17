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
    <main className="mx-auto max-w-4xl px-6 py-16">
      <h1 className="mb-8 text-2xl font-semibold tracking-tight">Manufacturers</h1>

      {error && (
        <p className="rounded-md border border-amber-300 bg-amber-50 p-4 text-sm text-amber-900 dark:border-amber-900 dark:bg-amber-950 dark:text-amber-200">
          Couldn&apos;t load manufacturers: {error}. Have you set up{' '}
          <code>.env.local</code> with your Supabase credentials?
        </p>
      )}

      {!error && manufacturers.length === 0 && (
        <p className="text-zinc-600 dark:text-zinc-400">No manufacturers found.</p>
      )}

      <ul className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        {manufacturers.map((m) => (
          <li key={m.id} className="rounded-lg border border-black/[.08] p-4 dark:border-white/[.145]">
            <Link href={`/manufacturers/${m.slug}`} className="font-medium hover:underline">
              {m.name}
            </Link>
            <p className="mt-1 text-sm text-zinc-600 dark:text-zinc-400">
              {m.country ?? 'Unknown country'} ·{' '}
              {m.product_line === 'electric_only' ? 'Electric only' : 'Mixed electric/conventional'}
            </p>
          </li>
        ))}
      </ul>
    </main>
  );
}
