import Image from 'next/image';
import Link from 'next/link';
import { headers } from 'next/headers';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { buildAlternates } from '@/lib/seo';
import { CONTENT_TYPE_LABELS, type ContentPageWithGroup } from '@/lib/supabase/content';

export async function generateMetadata() {
  return {
    title: 'Guides — Electric Yachts',
    alternates: await buildAlternates('/guides'),
  };
}

type GuideCard = ContentPageWithGroup & { image: string };

// Editorial fallback imagery for guides without a related model: EZ 28
// lifestyle shots — the only photography we hold usage rights for (Crooze
// partner agreement), and atmospheric enough to carry editorial cards.
const FALLBACK_IMAGES = [
  '/images/ez28/EZ28_14.jpg',
  '/images/ez28/EZ28_13.jpg',
  '/images/ez28/EZ28_4.jpg',
  '/images/ez28/EZ28_5.jpg',
];

async function getGuides(language: string): Promise<GuideCard[]> {
  const supabase = createSupabaseServerClient();
  const { data } = await supabase
    .from('content_pages')
    .select('*, content_page_groups(content_type, related_manufacturer_id, related_model_id)')
    .eq('language', language)
    .eq('status', 'published')
    .order('published_at', { ascending: false });

  const guides = (data as unknown as ContentPageWithGroup[]) ?? [];

  // Guides tied to a model use that model's hero image; the rest rotate
  // through the licensed fallback set deterministically.
  const modelIds = [
    ...new Set(guides.map((g) => g.content_page_groups.related_model_id).filter((id): id is string => !!id)),
  ];
  const heroByModel = new Map<string, string>();
  if (modelIds.length > 0) {
    const { data: models } = await supabase.from('models').select('id, hero_image_url').in('id', modelIds);
    for (const m of (models as { id: string; hero_image_url: string | null }[]) ?? []) {
      if (m.hero_image_url) heroByModel.set(m.id, m.hero_image_url);
    }
  }

  return guides.map((g, i) => ({
    ...g,
    image:
      (g.content_page_groups.related_model_id &&
        heroByModel.get(g.content_page_groups.related_model_id)) ||
      FALLBACK_IMAGES[i % FALLBACK_IMAGES.length],
  }));
}

export default async function GuidesPage() {
  const requestHeaders = await headers();
  const language = requestHeaders.get('x-market-language') ?? 'en';
  const guides = await getGuides(language);

  return (
    <main className="flex flex-1 flex-col">
      <div className="mx-auto w-full max-w-6xl px-6 pb-14 pt-16">
        <div className="grid gap-8 md:grid-cols-[1fr_1.3fr] md:items-end md:gap-16">
          <div>
            <span className="marker">Editorial</span>
            <h1 className="mt-3 font-serif text-4xl font-light tracking-tight md:text-5xl">Guides</h1>
          </div>
          <p className="font-serif text-lg font-light italic text-muted md:justify-self-end md:text-right">
            Buyer&apos;s guides, market overviews, and featured builds.
          </p>
        </div>
      </div>

      <section className="section-light flex-1 bg-paper px-6 py-14">
        <div className="mx-auto max-w-6xl">
          {guides.length === 0 && <p className="text-muted">No guides published yet.</p>}

          <ul className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
            {guides.map((guide) => (
              <li
                key={guide.id}
                className="group overflow-hidden rounded-lg border border-rule bg-white/70 transition-all hover:-translate-y-0.5 hover:border-copper hover:shadow-lg"
              >
                <Link href={`/guides/${guide.slug}`} className="block">
                  <div className="relative aspect-[16/9] overflow-hidden bg-cream-2">
                    <Image
                      src={guide.image}
                      alt=""
                      fill
                      sizes="(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 33vw"
                      className="object-cover transition-transform duration-500 group-hover:scale-[1.03]"
                    />
                    <span className="absolute left-3 top-3 z-10 rounded-full bg-ink/80 px-2.5 py-1 text-[10px] font-semibold uppercase tracking-[0.14em] text-paper">
                      {CONTENT_TYPE_LABELS[guide.content_page_groups.content_type]}
                    </span>
                  </div>
                  <div className="p-5">
                    <span className="font-serif text-lg leading-snug group-hover:text-copper">
                      {guide.title}
                    </span>
                    {guide.meta_description && (
                      <p className="mt-2 text-sm text-muted">{guide.meta_description}</p>
                    )}
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
