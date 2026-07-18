import Link from 'next/link';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { ModelCompareList } from '@/components/ModelCompareList';
import { buildAlternates } from '@/lib/seo';
import type { BoatCategory, ModelWithManufacturer } from '@/lib/supabase/types';

type PageProps = { searchParams: Promise<{ category?: string }> };

export async function generateMetadata({ searchParams }: PageProps) {
  const { category } = await searchParams;
  const search = category ? `?category=${category}` : '';
  return {
    title: 'Electric Yacht Models',
    alternates: await buildAlternates(`/models${search}`),
  };
}

async function getModels(category?: string): Promise<{ data: ModelWithManufacturer[]; error: string | null }> {
  try {
    const supabase = createSupabaseServerClient();
    let query = supabase.from('models').select('*, manufacturers(id, name, slug, logo_url, country)').order('name');
    if (category) query = query.eq('category', category as BoatCategory);
    const { data, error } = await query;

    if (error) return { data: [], error: error.message };
    return { data: (data as unknown as ModelWithManufacturer[]) ?? [], error: null };
  } catch (err) {
    return { data: [], error: err instanceof Error ? err.message : 'Unknown error' };
  }
}

export default async function ModelsPage({ searchParams }: PageProps) {
  const { category } = await searchParams;
  const { data: models, error } = await getModels(category);
  const withPricing = models.filter((m) => m.price_from_eur !== null).length;

  return (
    <main className="mx-auto max-w-5xl px-6 py-16">
      <div className="grid gap-8 border-b border-rule pb-12 md:grid-cols-[1fr_1.3fr] md:items-end md:gap-16">
        <div>
          <span className="marker">{category ? category.replace('_', ' ') : 'Models'}</span>
          <h1 className="mt-3 font-serif text-4xl font-light tracking-tight md:text-5xl">
            {category ? `${category.replace('_', ' ')}s`.replace(/^./, (c) => c.toUpperCase()) : 'Models'}
          </h1>
          {category && (
            <Link href="/models" className="mt-2 inline-block text-xs font-semibold uppercase tracking-[0.16em] text-muted hover:text-copper">
              ← Clear filter
            </Link>
          )}
        </div>
        <div className="flex gap-10 md:justify-end">
          <div>
            <div className="font-serif text-4xl font-light italic text-copper">{models.length}</div>
            <div className="mt-1 text-xs font-semibold uppercase tracking-[0.2em] text-muted">
              {category ? 'Matching models' : 'Total models'}
            </div>
          </div>
          <div>
            <div className="font-serif text-4xl font-light italic text-copper">{withPricing}</div>
            <div className="mt-1 text-xs font-semibold uppercase tracking-[0.2em] text-muted">With pricing</div>
          </div>
        </div>
      </div>

      <div className="mt-10">
        {error && (
          <p className="rounded-md border border-copper-soft bg-ink-2 p-4 text-sm text-paper">
            Couldn&apos;t load models: {error}. Have you set up <code>.env.local</code> with your
            Supabase credentials?
          </p>
        )}

        {!error && models.length === 0 && <p className="text-muted">No models found.</p>}

        {models.length > 0 && <ModelCompareList models={models} />}
      </div>
    </main>
  );
}
