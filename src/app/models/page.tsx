import { createSupabaseServerClient } from '@/lib/supabase/server';
import { ModelCompareList } from '@/components/ModelCompareList';
import { buildAlternates } from '@/lib/seo';
import type { ModelWithManufacturer } from '@/lib/supabase/types';

export async function generateMetadata() {
  return {
    title: 'Electric Yacht Models',
    alternates: await buildAlternates('/models'),
  };
}

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

export default async function ModelsPage() {
  const { data: models, error } = await getModels();
  const withPricing = models.filter((m) => m.price_from_eur !== null).length;

  return (
    <main className="mx-auto max-w-5xl px-6 py-16">
      <div className="grid gap-8 border-b border-rule pb-12 md:grid-cols-[1fr_1.3fr] md:items-end md:gap-16">
        <div>
          <span className="marker">Models</span>
          <h1 className="mt-3 font-serif text-4xl font-light tracking-tight md:text-5xl">Models</h1>
        </div>
        <div className="flex gap-10 md:justify-end">
          <div>
            <div className="font-serif text-4xl font-light italic text-copper">{models.length}</div>
            <div className="mt-1 text-xs font-semibold uppercase tracking-[0.2em] text-muted">Total models</div>
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
