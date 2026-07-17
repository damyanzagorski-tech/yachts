import { createSupabaseServerClient } from '@/lib/supabase/server';
import { ModelCompareList } from '@/components/ModelCompareList';
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

      {models.length > 0 && <ModelCompareList models={models} />}
    </main>
  );
}
