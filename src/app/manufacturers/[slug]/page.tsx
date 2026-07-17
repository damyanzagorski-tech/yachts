import Link from 'next/link';
import { notFound } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { buildAlternates } from '@/lib/seo';
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
  return {
    title: manufacturer ? `${manufacturer.name} — Electric Yachts` : 'Manufacturer',
    alternates: await buildAlternates(`/manufacturers/${slug}`),
  };
}

export default async function ManufacturerDetailPage({ params }: PageProps) {
  const { slug } = await params;
  const manufacturer = await getManufacturer(slug);
  if (!manufacturer) notFound();

  const models = await getModelsForManufacturer(manufacturer.id);

  return (
    <main className="mx-auto max-w-4xl px-6 py-16">
      <Link
        href="/manufacturers"
        className="block text-xs font-semibold uppercase tracking-[0.16em] text-ink-soft hover:text-copper"
      >
        ← All manufacturers
      </Link>

      <div className="mt-6">
        <span className="marker">{manufacturer.country ?? 'Manufacturer'}</span>
      </div>
      <h1 className="mt-3 font-serif text-3xl font-light tracking-tight">{manufacturer.name}</h1>
      <p className="mt-2 text-xs font-semibold uppercase tracking-[0.16em] text-ink-soft">
        {manufacturer.product_line === 'electric_only' ? 'Electric only' : 'Mixed electric/conventional'}
        {manufacturer.is_verified && ' · Verified'}
      </p>

      {manufacturer.website && (
        <a
          href={manufacturer.website}
          target="_blank"
          rel="noopener noreferrer"
          className="mt-4 inline-block text-sm font-semibold text-copper hover:text-copper-soft"
        >
          Visit website ↗
        </a>
      )}

      {manufacturer.description && (
        <p className="mt-6 max-w-2xl text-ink-soft">{manufacturer.description}</p>
      )}

      {manufacturer.founded_year && (
        <div className="spec-row mt-6 max-w-xs">
          <span className="spec-label">Founded</span>
          <span className="spec-value">{manufacturer.founded_year}</span>
        </div>
      )}

      <h2 className="mt-12 mb-4 font-serif text-xl font-light">
        Models <span className="text-copper">({models.length})</span>
      </h2>

      {models.length === 0 && <p className="text-ink-soft">No models listed for this manufacturer yet.</p>}

      <ul className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        {models.map((model) => (
          <li key={model.id} className="rounded-lg border border-rule p-5 transition-colors hover:border-copper">
            <Link href={`/models/${model.slug}`} className="font-serif text-lg hover:text-copper">
              {model.name}
            </Link>
            <p className="mt-2 text-xs font-semibold uppercase tracking-[0.16em] text-ink-soft">
              {model.category.replace('_', ' ')}
            </p>
            <p className="mt-2 font-serif text-sm italic text-copper">{formatPrice(model)}</p>
          </li>
        ))}
      </ul>
    </main>
  );
}
