import Image from 'next/image';
import Link from 'next/link';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { buildAlternates } from '@/lib/seo';
import { VerifiedBadge } from '@/components/VerifiedBadge';
import type { Manufacturer } from '@/lib/supabase/types';

export async function generateMetadata() {
  return {
    title: 'Electric Yacht Manufacturers',
    alternates: await buildAlternates('/manufacturers'),
  };
}

type ModelPreview = {
  manufacturer_id: string;
  hero_image_url: string | null;
  is_featured: boolean;
};

type ManufacturerCard = Manufacturer & {
  modelCount: number;
  previewImage: string | null;
};

async function getManufacturers(): Promise<{ data: ManufacturerCard[]; error: string | null }> {
  try {
    const supabase = createSupabaseServerClient();
    const [{ data, error }, { data: models }] = await Promise.all([
      supabase.from('manufacturers').select('*').order('name'),
      supabase.from('models').select('manufacturer_id, hero_image_url, is_featured'),
    ]);

    if (error) return { data: [], error: error.message };

    // One representative model image per manufacturer: featured first,
    // otherwise the first model that has a hero image.
    const byManufacturer = new Map<string, ModelPreview[]>();
    for (const m of (models as ModelPreview[]) ?? []) {
      const list = byManufacturer.get(m.manufacturer_id) ?? [];
      list.push(m);
      byManufacturer.set(m.manufacturer_id, list);
    }

    const cards: ManufacturerCard[] = ((data as Manufacturer[]) ?? []).map((m) => {
      const own = byManufacturer.get(m.id) ?? [];
      const preview =
        own.find((x) => x.is_featured && x.hero_image_url) ?? own.find((x) => x.hero_image_url);
      return { ...m, modelCount: own.length, previewImage: preview?.hero_image_url ?? null };
    });

    // Verified partners lead, rest stay A-Z (matches the models listing).
    cards.sort((a, b) => {
      const ap = a.status === 'partner' ? 0 : 1;
      const bp = b.status === 'partner' ? 0 : 1;
      return ap - bp || a.name.localeCompare(b.name);
    });

    return { data: cards, error: null };
  } catch (err) {
    return { data: [], error: err instanceof Error ? err.message : 'Unknown error' };
  }
}

export default async function ManufacturersPage() {
  const { data: manufacturers, error } = await getManufacturers();
  const electricOnly = manufacturers.filter((m) => m.product_line === 'electric_only').length;

  return (
    <main className="flex flex-1 flex-col">
      <div className="mx-auto w-full max-w-6xl px-6 pb-14 pt-16">
        <div className="grid gap-8 md:grid-cols-[1fr_1.3fr] md:items-end md:gap-16">
          <div>
            <span className="marker">Builders</span>
            <h1 className="mt-3 font-serif text-4xl font-light tracking-tight md:text-5xl">Manufacturers</h1>
          </div>
          <div className="flex gap-10 md:justify-end">
            <div>
              <div className="font-serif text-4xl font-light italic text-copper">{manufacturers.length}</div>
              <div className="mt-1 text-xs font-semibold uppercase tracking-[0.2em] text-muted">Total builders</div>
            </div>
            <div>
              <div className="font-serif text-4xl font-light italic text-copper">{electricOnly}</div>
              <div className="mt-1 text-xs font-semibold uppercase tracking-[0.2em] text-muted">Electric only</div>
            </div>
          </div>
        </div>
      </div>

      <section className="section-light flex-1 bg-paper px-6 py-14">
        <div className="mx-auto max-w-6xl">
          {error && (
            <p className="rounded-md border border-copper bg-cream p-4 text-sm">
              Couldn&apos;t load manufacturers: {error}. Have you set up <code>.env.local</code> with your
              Supabase credentials?
            </p>
          )}

          {!error && manufacturers.length === 0 && <p className="text-muted">No manufacturers found.</p>}

          <ul className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
            {manufacturers.map((m) => (
              <li
                key={m.id}
                className="group overflow-hidden rounded-lg border border-rule bg-white/70 transition-all hover:-translate-y-0.5 hover:border-copper hover:shadow-lg"
              >
                <Link href={`/manufacturers/${m.slug}`} className="block">
                  <div className="relative aspect-[16/9] overflow-hidden bg-cream-2">
                    {m.status === 'partner' && <VerifiedBadge />}
                    {m.previewImage ? (
                      <Image
                        src={m.previewImage}
                        alt={`${m.name} electric yacht`}
                        fill
                        sizes="(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 33vw"
                        className="object-cover transition-transform duration-500 group-hover:scale-[1.03]"
                      />
                    ) : (
                      <div className="flex h-full items-center justify-center">
                        <span className="font-serif text-5xl font-light italic text-sand">
                          {m.name.charAt(0)}
                        </span>
                      </div>
                    )}
                  </div>
                  <div className="p-5">
                    <div className="flex items-baseline justify-between gap-3">
                      <span className="font-serif text-lg group-hover:text-copper">{m.name}</span>
                      <span className="shrink-0 font-serif text-sm italic text-copper">
                        {m.modelCount} {m.modelCount === 1 ? 'model' : 'models'}
                      </span>
                    </div>
                    <p className="mt-1.5 text-xs font-semibold uppercase tracking-[0.16em] text-muted">
                      {m.country ?? 'Unknown country'} ·{' '}
                      {m.product_line === 'electric_only' ? 'Electric only' : 'Mixed'}
                    </p>
                  </div>
                </Link>
              </li>
            ))}
          </ul>
        </div>
      </section>
    </main>
  );
}
