import Link from 'next/link';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import type { ModelWithManufacturer } from '@/lib/supabase/types';

export const metadata = {
  title: 'Electric Yacht Models',
};

async function getModels(): Promise<{ data: ModelWithManufacturer[]; error: string | null }> {
  try {
    const supabase = createSupabaseServerClient();
    const { data, error } = await supabase
      .from('models')
      .select('*, manufacturers(id, name, slug, logo_url, country)')
      .order('name');

    if (error) return { data: [], error: error.message };
    return { data: (data as unknown as ModelWithManufacturer[]) ?? [], error: null };
  } catch (err) {
    return { data: [], error: err instanceof Error ? err.message : 'Unknown error' };
  }
}

function formatPrice(model: ModelWithManufacturer): string {
  if (!model.price_from_eur) return 'Price on request';
  const from = new Intl.NumberFormat('en-EU', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 }).format(
    model.price_from_eur
  );
  return `From ${from}`;
}

export default async function ModelsPage() {
  const { data: models, error } = await getModels();

  return (
    <main className="mx-auto max-w-4xl px-6 py-16">
      <h1 className="mb-8 text-2xl font-semibold tracking-tight">Models</h1>

      {error && (
        <p className="rounded-md border border-amber-300 bg-amber-50 p-4 text-sm text-amber-900 dark:border-amber-900 dark:bg-amber-950 dark:text-amber-200">
          Couldn&apos;t load models: {error}. Have you set up <code>.env.local</code> with your
          Supabase credentials?
        </p>
      )}

      {!error && models.length === 0 && (
        <p className="text-zinc-600 dark:text-zinc-400">No models found.</p>
      )}

      <ul className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        {models.map((model) => (
          <li key={model.id} className="rounded-lg border border-black/[.08] p-4 dark:border-white/[.145]">
            <Link href={`/models/${model.slug}`} className="font-medium hover:underline">
              {model.name}
            </Link>
            <p className="mt-1 text-sm text-zinc-600 dark:text-zinc-400">
              {model.manufacturers?.name} · {model.category.replace('_', ' ')}
            </p>
            <p className="mt-1 text-sm text-zinc-600 dark:text-zinc-400">{formatPrice(model)}</p>
          </li>
        ))}
      </ul>
    </main>
  );
}
