import Link from 'next/link';
import { notFound } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import type { Manufacturer, ModelWithManufacturer } from '@/lib/supabase/types';

type PageProps = { params: Promise<{ slug: string }> };

async function getManufacturer(slug: string): Promise<Manufacturer | null> {
  const supabase = createSupabaseServerClient();
  const { data } = await supabase
    .from('manufacturers')
    .select(
      'id, name, slug, country, website, logo_url, description, founded_year, product_line, is_verified, created_at, updated_at, status, has_affiliate_program, listing_tier'
    )
    .eq('slug', slug)
    .maybeSingle();
  return data;
}

async function getModelsForManufacturer(manufacturerId: string): Promise<ModelWithManufacturer[]> {
  const supabase = createSupabaseServerClient();
  const { data } = await supabase
    .from('models')
    .select('*, manufacturers(id, name, slug, logo_url, country)')
    .eq('manufacturer_id', manufacturerId)
    .order('name');
  return (data as unknown as ModelWithManufacturer[]) ?? [];
}

function formatPrice(model: ModelWithManufacturer): string {
  if (!model.price_from_eur) return 'Price on request';
  const from = new Intl.NumberFormat('en-EU', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 }).format(
    model.price_from_eur
  );
  return `From ${from}`;
}

export async function generateMetadata({ params }: PageProps) {
  const { slug } = await params;
  const manufacturer = await getManufacturer(slug);
  return { title: manufacturer ? `${manufacturer.name} — Electric Yachts` : 'Manufacturer' };
}

export default async function ManufacturerDetailPage({ params }: PageProps) {
  const { slug } = await params;
  const manufacturer = await getManufacturer(slug);
  if (!manufacturer) notFound();

  const models = await getModelsForManufacturer(manufacturer.id);

  return (
    <main className="mx-auto max-w-4xl px-6 py-16">
      <Link href="/manufacturers" className="text-sm text-zinc-600 hover:underline dark:text-zinc-400">
        ← All manufacturers
      </Link>

      <h1 className="mt-4 text-2xl font-semibold tracking-tight">{manufacturer.name}</h1>
      <p className="mt-1 text-sm text-zinc-600 dark:text-zinc-400">
        {manufacturer.country ?? 'Unknown country'} ·{' '}
        {manufacturer.product_line === 'electric_only' ? 'Electric only' : 'Mixed electric/conventional'}
        {manufacturer.is_verified && ' · Verified'}
      </p>

      {manufacturer.website && (
        <a
          href={manufacturer.website}
          target="_blank"
          rel="noopener noreferrer"
          className="mt-2 inline-block text-sm font-medium hover:underline"
        >
          Visit website ↗
        </a>
      )}

      {manufacturer.description && (
        <p className="mt-6 max-w-2xl text-zinc-700 dark:text-zinc-300">{manufacturer.description}</p>
      )}

      {manufacturer.founded_year && (
        <p className="mt-2 text-sm text-zinc-600 dark:text-zinc-400">Founded {manufacturer.founded_year}</p>
      )}

      <h2 className="mt-12 mb-4 text-lg font-semibold">Models ({models.length})</h2>

      {models.length === 0 && (
        <p className="text-zinc-600 dark:text-zinc-400">No models listed for this manufacturer yet.</p>
      )}

      <ul className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        {models.map((model) => (
          <li key={model.id} className="rounded-lg border border-black/[.08] p-4 dark:border-white/[.145]">
            <Link href={`/models/${model.slug}`} className="font-medium hover:underline">
              {model.name}
            </Link>
            <p className="mt-1 text-sm text-zinc-600 dark:text-zinc-400">
              {model.category.replace('_', ' ')} · {formatPrice(model)}
            </p>
          </li>
        ))}
      </ul>
    </main>
  );
}
