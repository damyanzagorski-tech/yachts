import Link from 'next/link';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import type { ModelWithManufacturer } from '@/lib/supabase/types';

const MAX_COMPARE = 4;

type PageProps = { searchParams: Promise<{ slugs?: string }> };

async function getModels(slugs: string[]): Promise<ModelWithManufacturer[]> {
  if (slugs.length === 0) return [];
  const supabase = createSupabaseServerClient();
  const { data } = await supabase
    .from('models')
    .select('*, manufacturers(id, name, slug, logo_url, country)')
    .in('slug', slugs);

  const found = (data as unknown as ModelWithManufacturer[]) ?? [];
  // Preserve the order the user picked them in, rather than whatever the DB returns.
  return slugs.map((slug) => found.find((m) => m.slug === slug)).filter((m): m is ModelWithManufacturer => !!m);
}

const eurFormatter = new Intl.NumberFormat('en-EU', {
  style: 'currency',
  currency: 'EUR',
  maximumFractionDigits: 0,
});

function formatPrice(model: ModelWithManufacturer): string {
  return model.price_from_eur ? `From ${eurFormatter.format(model.price_from_eur)}` : 'Price on request';
}

type Row = { label: string; value: (m: ModelWithManufacturer) => string };

const ROWS: Row[] = [
  { label: 'Manufacturer', value: (m) => m.manufacturers?.name ?? '—' },
  { label: 'Category', value: (m) => m.category.replace('_', ' ') },
  { label: 'Propulsion', value: (m) => (m.propulsion_type === 'hybrid_electric' ? 'Hybrid electric' : 'Electric') },
  { label: 'Market tier', value: (m) => m.market_tier?.replace('_', ' ') ?? '—' },
  { label: 'Price', value: (m) => formatPrice(m) },
  { label: 'Length', value: (m) => (m.length_m ? `${m.length_m} m` : '—') },
  { label: 'Beam', value: (m) => (m.beam_m ? `${m.beam_m} m` : '—') },
  { label: 'Passenger capacity', value: (m) => (m.passenger_capacity ? `${m.passenger_capacity}` : '—') },
  { label: 'Battery', value: (m) => (m.battery_kwh ? `${m.battery_kwh} kWh` : '—') },
  { label: 'Motor power', value: (m) => (m.motor_power_kw ? `${m.motor_power_kw} kW` : '—') },
  { label: 'Top speed', value: (m) => (m.top_speed_knots ? `${m.top_speed_knots} knots` : '—') },
  { label: 'Range', value: (m) => (m.range_nm ? `${m.range_nm} nm` : '—') },
  { label: 'Charging time', value: (m) => (m.charging_time_hours ? `${m.charging_time_hours} hours` : '—') },
];

export const metadata = { title: 'Compare Electric Yachts' };

export default async function ComparePage({ searchParams }: PageProps) {
  const { slugs: slugsParam } = await searchParams;
  const requestedSlugs = (slugsParam ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  const cappedSlugs = requestedSlugs.slice(0, MAX_COMPARE);

  const models = await getModels(cappedSlugs);

  if (requestedSlugs.length === 0) {
    return (
      <main className="mx-auto max-w-4xl px-6 py-16">
        <h1 className="mb-4 text-2xl font-semibold tracking-tight">Compare</h1>
        <p className="text-zinc-600 dark:text-zinc-400">
          Pick a couple of models to compare from the{' '}
          <Link href="/models" className="underline">
            models page
          </Link>
          .
        </p>
      </main>
    );
  }

  if (models.length < 2) {
    return (
      <main className="mx-auto max-w-4xl px-6 py-16">
        <h1 className="mb-4 text-2xl font-semibold tracking-tight">Compare</h1>
        <p className="text-zinc-600 dark:text-zinc-400">
          Couldn&apos;t find enough matching models to compare. Head back to the{' '}
          <Link href="/models" className="underline">
            models page
          </Link>{' '}
          and select at least two.
        </p>
      </main>
    );
  }

  return (
    <main className="mx-auto max-w-6xl px-6 py-16">
      <Link href="/models" className="text-sm text-zinc-600 hover:underline dark:text-zinc-400">
        ← All models
      </Link>

      <h1 className="mt-4 mb-2 text-2xl font-semibold tracking-tight">Compare</h1>
      {requestedSlugs.length > MAX_COMPARE && (
        <p className="mb-4 text-sm text-amber-700 dark:text-amber-400">
          Showing the first {MAX_COMPARE} of {requestedSlugs.length} selected models.
        </p>
      )}

      <div className="overflow-x-auto">
        <table className="w-full min-w-[600px] border-collapse text-sm">
          <thead>
            <tr>
              <th className="w-40" />
              {models.map((m) => (
                <th key={m.id} className="border-b border-black/[.08] px-4 py-3 text-left dark:border-white/[.145]">
                  <Link href={`/models/${m.slug}`} className="font-medium hover:underline">
                    {m.name}
                  </Link>
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {ROWS.map((row) => (
              <tr key={row.label}>
                <th className="border-b border-black/[.06] px-4 py-2 text-left font-normal text-zinc-600 dark:border-white/[.1] dark:text-zinc-400">
                  {row.label}
                </th>
                {models.map((m) => (
                  <td key={m.id} className="border-b border-black/[.06] px-4 py-2 dark:border-white/[.1]">
                    {row.value(m)}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </main>
  );
}
