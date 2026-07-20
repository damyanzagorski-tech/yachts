import { createSupabaseServerClient } from '@/lib/supabase/server';
import { ModelMarketplace } from '@/components/marketplace/ModelMarketplace';
import { countActiveFilters, parseFilters, type MarketplaceModel } from '@/lib/marketplace/filters';
import { buildAlternates } from '@/lib/seo';
import { CATEGORY_LABELS, type ModelWithManufacturer } from '@/lib/supabase/types';

type PageProps = { searchParams: Promise<Record<string, string | string[] | undefined>> };

type ModelRow = ModelWithManufacturer & {
  model_powertrains: { motor_count: number; is_primary: boolean }[] | null;
};

export async function generateMetadata({ searchParams }: PageProps) {
  const sp = await searchParams;
  const filters = parseFilters(sp);
  // Single-category deep links stay indexable category pages; any other
  // filter combination canonicalizes to the bare listing so arbitrary
  // permutations don't compete in search.
  const isCategoryOnly =
    filters.categories.length === 1 &&
    countActiveFilters(filters) === 1 &&
    filters.categories[0] in CATEGORY_LABELS;
  const path = isCategoryOnly ? `/models?category=${filters.categories[0]}` : '/models';
  return {
    title: isCategoryOnly
      ? `Electric ${CATEGORY_LABELS[filters.categories[0]]}`
      : 'Electric Yacht Models',
    alternates: await buildAlternates(path),
  };
}

async function getModels(): Promise<{ data: MarketplaceModel[]; error: string | null }> {
  try {
    const supabase = createSupabaseServerClient();
    const { data, error } = await supabase
      .from('models')
      .select('*, manufacturers(id, name, slug, logo_url, country, is_verified, status), model_powertrains(motor_count, is_primary)')
      .order('name');

    if (error) return { data: [], error: error.message };

    const models: MarketplaceModel[] = ((data as unknown as ModelRow[]) ?? []).map((row) => {
      const { model_powertrains, ...model } = row;
      const primary = model_powertrains?.find((p) => p.is_primary) ?? model_powertrains?.[0];
      return { ...model, engine_count: primary?.motor_count ?? null };
    });
    return { data: models, error: null };
  } catch (err) {
    return { data: [], error: err instanceof Error ? err.message : 'Unknown error' };
  }
}

export default async function ModelsPage({ searchParams }: PageProps) {
  const sp = await searchParams;
  const initialFilters = parseFilters(sp);
  const { data: models, error } = await getModels();
  const withPricing = models.filter((m) => m.price_from_eur !== null).length;

  return (
    <main className="mx-auto max-w-6xl px-6 py-16">
      <div className="grid gap-8 border-b border-rule pb-12 md:grid-cols-[1fr_1.3fr] md:items-end md:gap-16">
        <div>
          <span className="marker">Marketplace</span>
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

      {error && (
        <p className="mt-10 rounded-md border border-copper-soft bg-ink-2 p-4 text-sm text-paper">
          Couldn&apos;t load models: {error}. Have you set up <code>.env.local</code> with your Supabase
          credentials?
        </p>
      )}

      {!error && <ModelMarketplace models={models} initialFilters={initialFilters} />}
    </main>
  );
}
