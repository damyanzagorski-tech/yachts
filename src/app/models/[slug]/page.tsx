import Link from 'next/link';
import { notFound } from 'next/navigation';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import type { ModelPowertrain, ModelWithManufacturer } from '@/lib/supabase/types';

type PageProps = { params: Promise<{ slug: string }> };

async function getModel(slug: string): Promise<ModelWithManufacturer | null> {
  const supabase = createSupabaseServerClient();
  const { data } = await supabase
    .from('models')
    .select('*, manufacturers(id, name, slug, logo_url, country)')
    .eq('slug', slug)
    .maybeSingle();
  return data as unknown as ModelWithManufacturer | null;
}

async function getPowertrains(modelId: string): Promise<ModelPowertrain[]> {
  const supabase = createSupabaseServerClient();
  const { data } = await supabase
    .from('model_powertrains')
    .select('*')
    .eq('model_id', modelId)
    .order('is_primary', { ascending: false });
  return data ?? [];
}

const eurFormatter = new Intl.NumberFormat('en-EU', {
  style: 'currency',
  currency: 'EUR',
  maximumFractionDigits: 0,
});

function formatPriceRange(model: ModelWithManufacturer): string {
  if (!model.price_from_eur) return 'Price on request';
  if (model.price_to_eur && model.price_to_eur !== model.price_from_eur) {
    return `${eurFormatter.format(model.price_from_eur)} – ${eurFormatter.format(model.price_to_eur)}`;
  }
  return `From ${eurFormatter.format(model.price_from_eur)}`;
}

function Spec({ label, value }: { label: string; value: string | number | null | undefined }) {
  if (value === null || value === undefined || value === '') return null;
  return (
    <div className="flex justify-between border-b border-black/[.06] py-2 text-sm dark:border-white/[.1]">
      <dt className="text-zinc-600 dark:text-zinc-400">{label}</dt>
      <dd className="font-medium">{value}</dd>
    </div>
  );
}

export async function generateMetadata({ params }: PageProps) {
  const { slug } = await params;
  const model = await getModel(slug);
  return { title: model ? `${model.name} — Electric Yachts` : 'Model' };
}

export default async function ModelDetailPage({ params }: PageProps) {
  const { slug } = await params;
  const model = await getModel(slug);
  if (!model) notFound();

  const powertrains = await getPowertrains(model.id);

  return (
    <main className="mx-auto max-w-4xl px-6 py-16">
      <Link href="/models" className="text-sm text-zinc-600 hover:underline dark:text-zinc-400">
        ← All models
      </Link>

      <h1 className="mt-4 text-2xl font-semibold tracking-tight">{model.name}</h1>
      <p className="mt-1 text-sm text-zinc-600 dark:text-zinc-400">
        <Link href={`/manufacturers/${model.manufacturers.slug}`} className="hover:underline">
          {model.manufacturers.name}
        </Link>{' '}
        · {model.category.replace('_', ' ')} ·{' '}
        {model.propulsion_type === 'hybrid_electric' ? 'Hybrid electric' : 'Electric'}
        {model.market_tier && ` · ${model.market_tier.replace('_', ' ')}`}
      </p>

      <p className="mt-2 text-lg font-medium">{formatPriceRange(model)}</p>

      {model.description && (
        <p className="mt-6 max-w-2xl text-zinc-700 dark:text-zinc-300">{model.description}</p>
      )}

      <h2 className="mt-10 mb-2 text-lg font-semibold">Specifications</h2>
      <dl className="max-w-md">
        <Spec label="Length" value={model.length_m ? `${model.length_m} m` : null} />
        <Spec label="Beam" value={model.beam_m ? `${model.beam_m} m` : null} />
        <Spec label="Draft" value={model.draft_m ? `${model.draft_m} m` : null} />
        <Spec label="Weight" value={model.weight_kg ? `${model.weight_kg.toLocaleString('en-EU')} kg` : null} />
        <Spec label="Passenger capacity" value={model.passenger_capacity} />
        <Spec label="Battery" value={model.battery_kwh ? `${model.battery_kwh} kWh` : null} />
        <Spec label="Motor power" value={model.motor_power_kw ? `${model.motor_power_kw} kW` : null} />
        <Spec label="Top speed" value={model.top_speed_knots ? `${model.top_speed_knots} knots` : null} />
        <Spec label="Range" value={model.range_nm ? `${model.range_nm} nm` : null} />
        <Spec
          label="Charging time"
          value={model.charging_time_hours ? `${model.charging_time_hours} hours` : null}
        />
        <Spec label="CE category" value={model.ce_category} />
      </dl>

      {powertrains.length > 0 && (
        <>
          <h2 className="mt-10 mb-4 text-lg font-semibold">
            Powertrain options {powertrains.length > 1 && `(${powertrains.length})`}
          </h2>
          <ul className="flex flex-col gap-4">
            {powertrains.map((pt) => (
              <li key={pt.id} className="rounded-lg border border-black/[.08] p-4 dark:border-white/[.145]">
                <p className="font-medium">
                  {[pt.motor_brand, pt.motor_model].filter(Boolean).join(' ') || 'Motor/battery details not disclosed'}
                  {pt.is_primary && powertrains.length > 1 && (
                    <span className="ml-2 text-xs font-normal text-zinc-500">(primary)</span>
                  )}
                </p>
                <dl className="mt-2 grid grid-cols-2 gap-x-4 text-sm text-zinc-600 dark:text-zinc-400">
                  <Spec label="Motors" value={pt.motor_count > 1 ? `${pt.motor_count}x` : null} />
                  <Spec label="Power" value={pt.motor_power_kw ? `${pt.motor_power_kw} kW` : null} />
                  <Spec label="Battery" value={pt.battery_kwh ? `${pt.battery_kwh} kWh (${pt.battery_brand ?? 'unspecified brand'})` : null} />
                  <Spec label="Top speed" value={pt.top_speed_knots ? `${pt.top_speed_knots} kn` : null} />
                  <Spec label="Range" value={pt.range_nm ? `${pt.range_nm} nm` : null} />
                  <Spec label="Price" value={pt.price_from_eur ? eurFormatter.format(pt.price_from_eur) : null} />
                </dl>
                {pt.notes && <p className="mt-2 text-sm text-zinc-600 dark:text-zinc-400">{pt.notes}</p>}
              </li>
            ))}
          </ul>
        </>
      )}
    </main>
  );
}
