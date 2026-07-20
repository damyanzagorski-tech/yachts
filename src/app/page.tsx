import Image from 'next/image';
import Link from 'next/link';
import { headers } from 'next/headers';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { buildAlternates } from '@/lib/seo';
import { ScrollReveal } from '@/components/ScrollReveal';
import { VerifiedBadge } from '@/components/VerifiedBadge';
import { CATEGORY_LABELS, type BoatCategory, type ModelWithManufacturer } from '@/lib/supabase/types';
import { CONTENT_TYPE_LABELS, type ContentPageWithGroup } from '@/lib/supabase/content';

export async function generateMetadata() {
  return { alternates: await buildAlternates('/') };
}

const eurFormatter = new Intl.NumberFormat('en-EU', {
  style: 'currency',
  currency: 'EUR',
  maximumFractionDigits: 0,
});

function formatPrice(model: ModelWithManufacturer): string {
  return model.price_from_eur ? `From ${eurFormatter.format(model.price_from_eur)}` : 'Price on request';
}

async function getCounts() {
  const supabase = createSupabaseServerClient();
  try {
    const [{ count: manufacturersCount }, { count: modelsCount }, { data: categoryRows }] = await Promise.all([
      supabase.from('manufacturers').select('*', { count: 'exact', head: true }),
      supabase.from('models').select('*', { count: 'exact', head: true }),
      supabase.from('models').select('category'),
    ]);

    const categoryCounts = new Map<BoatCategory, number>();
    for (const row of (categoryRows as unknown as { category: BoatCategory }[]) ?? []) {
      categoryCounts.set(row.category, (categoryCounts.get(row.category) ?? 0) + 1);
    }

    return { manufacturersCount: manufacturersCount ?? 0, modelsCount: modelsCount ?? 0, categoryCounts };
  } catch {
    return { manufacturersCount: 0, modelsCount: 0, categoryCounts: new Map<BoatCategory, number>() };
  }
}

async function getFeaturedModels(): Promise<ModelWithManufacturer[]> {
  const supabase = createSupabaseServerClient();
  try {
    const { data: featured } = await supabase
      .from('models')
      .select('*, manufacturers(id, name, slug, logo_url, country, is_verified, status)')
      .eq('is_featured', true)
      .order('created_at', { ascending: false })
      .limit(4);

    const models = (featured as unknown as ModelWithManufacturer[]) ?? [];
    if (models.length >= 4) return models;

    const { data: recent } = await supabase
      .from('models')
      .select('*, manufacturers(id, name, slug, logo_url, country, is_verified, status)')
      .eq('is_featured', false)
      .order('created_at', { ascending: false })
      .limit(4 - models.length);

    return [...models, ...((recent as unknown as ModelWithManufacturer[]) ?? [])];
  } catch {
    return [];
  }
}

async function getLatestGuides(language: string): Promise<ContentPageWithGroup[]> {
  const supabase = createSupabaseServerClient();
  try {
    const { data } = await supabase
      .from('content_pages')
      .select('*, content_page_groups(content_type, related_manufacturer_id, related_model_id)')
      .eq('language', language)
      .eq('status', 'published')
      .order('published_at', { ascending: false })
      .limit(3);
    return (data as unknown as ContentPageWithGroup[]) ?? [];
  } catch {
    return [];
  }
}

const QUICK_FILTERS: BoatCategory[] = ['day_boat', 'catamaran', 'sport', 'tender', 'cruiser'];
const BROWSE_CATEGORIES: BoatCategory[] = ['day_boat', 'catamaran', 'sport', 'tender', 'cruiser', 'other'];

const JOURNEY_STEPS = [
  {
    n: '01',
    title: 'Learn',
    body: "Buyer's guides and market overviews for electric and hybrid-electric yachts.",
    href: '/guides',
    cta: 'Start learning',
  },
  {
    n: '02',
    title: 'Browse',
    body: 'Manufacturers and models tracked with verified specifications.',
    href: '/manufacturers',
    cta: 'View manufacturers',
  },
  {
    n: '03',
    title: 'Compare',
    body: 'Put any two or more models side by side across every spec.',
    href: '/models',
    cta: 'Compare models',
  },
  {
    n: '04',
    title: 'Connect',
    body: 'Every model links straight to the manufacturer to enquire directly.',
    href: '/models',
    cta: 'Find a model',
  },
];

export default async function Home() {
  const requestHeaders = await headers();
  const language = requestHeaders.get('x-market-language') ?? 'en';

  const [{ manufacturersCount, modelsCount, categoryCounts }, featuredModels, latestGuides] = await Promise.all([
    getCounts(),
    getFeaturedModels(),
    getLatestGuides(language),
  ]);

  const tickerItems = [
    'Fully Electric',
    `${manufacturersCount} Manufacturers`,
    `${modelsCount} Models`,
    'Verified Specifications',
    'Side-by-Side Compare',
    'Day Boats',
    'Catamarans',
    'Sport Boats',
    "Buyer's Guides",
  ];

  return (
    <>
      <ScrollReveal />

      {/* HERO — full-viewport navy, centered serif title, corner meta, scroll cue */}
      <section className="hero-depth relative -mt-16 flex min-h-[100vh] flex-col overflow-hidden">
        <div className="relative z-[2] mx-auto grid w-full max-w-6xl flex-1 grid-rows-[1fr_auto_auto] px-6 pb-24 pt-32">
          <div />
          <div className="text-center">
            <h1 className="font-serif text-[clamp(56px,11vw,170px)] font-light leading-[0.88] tracking-[-0.04em]">
              Electric Yacht
              <span className="block italic text-copper-soft">Market</span>
            </h1>
          </div>
          <div className="mt-8 text-center text-[13px] uppercase tracking-[0.42em] text-cream">
            The database of electric &amp; hybrid-electric yachts
          </div>
        </div>

        <div className="absolute bottom-7 left-10 z-[3] hidden text-[11px] uppercase tracking-[0.25em] text-cream/70 md:block">
          {manufacturersCount} manufacturers · <b className="font-medium text-copper-soft">{modelsCount} models</b>
        </div>
        <div className="absolute bottom-7 right-10 z-[3] hidden text-right text-[11px] uppercase tracking-[0.25em] text-cream/70 md:block">
          Verified specs · <b className="font-medium text-copper-soft">Side-by-side compare</b>
        </div>
        <div className="absolute bottom-7 left-1/2 z-[3] -translate-x-1/2">
          <div className="scroll-cue">
            <span>Scroll</span>
            <span className="line" />
          </div>
        </div>
      </section>

      {/* TICKER */}
      <div className="ticker" aria-hidden="true">
        <div className="track">
          {[...tickerItems, ...tickerItems].map((item, i) => (
            <span key={i}>{item}</span>
          ))}
        </div>
      </div>

      {/* MANIFESTO — light section, sticky left heading, pull quote right */}
      <section className="section-light relative bg-paper px-6 py-28 md:py-36">
        <div className="ghost-num left-10 top-16">01</div>
        <div className="mx-auto max-w-6xl">
          <div className="grid gap-16 md:grid-cols-[1fr_1.1fr] md:gap-24">
            <div className="reveal md:sticky md:top-28 md:self-start">
              <span className="marker">The database</span>
              <h2 className="mt-4 max-w-[14ch] font-serif text-[clamp(40px,6vw,78px)] font-light leading-[1.02] tracking-[-0.015em]">
                Every electric yacht, <em className="text-copper">in one place.</em>
              </h2>
            </div>
            <div className="reveal">
              <p className="pull mb-10">
                {manufacturersCount} manufacturers and {modelsCount} models — tracked, verified, and compared.
              </p>
              <p className="mb-5 max-w-[56ch] text-[17px] leading-[1.7] text-muted">
                The electric yacht market is scattered across dozens of builder sites, press releases, and
                boat-show coverage — with specifications that rarely agree. We track every manufacturer and
                model in one structured database, verified against the sources.
              </p>
              <p className="mb-8 max-w-[56ch] text-[17px] leading-[1.7] text-muted">
                Browse by category, read the buyer&apos;s guides, and put any models side by side before you
                talk to a dealer.
              </p>
              <div className="flex flex-wrap gap-2">
                {QUICK_FILTERS.map((cat) => (
                  <Link
                    key={cat}
                    href={`/models?category=${cat}`}
                    className="rounded-full border border-rule-strong px-4 py-2 text-xs font-semibold uppercase tracking-[0.12em] text-muted transition-colors hover:border-copper hover:text-copper"
                  >
                    {CATEGORY_LABELS[cat]}
                  </Link>
                ))}
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* JOURNEY — navy section, 1px-gap feature grid */}
      <section className="bg-ink px-6 py-28 md:py-36">
        <div className="mx-auto max-w-6xl">
          <div className="reveal">
            <span className="marker">How it works</span>
            <h2 className="mt-4 font-serif text-[clamp(40px,6vw,78px)] font-light leading-[1.02] tracking-[-0.015em]">
              From research to <em className="text-copper-soft">reaching out.</em>
            </h2>
          </div>
          <div className="reveal-stagger mt-14 grid gap-px border border-white/10 bg-white/10 sm:grid-cols-2 lg:grid-cols-4">
            {JOURNEY_STEPS.map((step) => (
              <Link key={step.n} href={step.href} className="group bg-ink p-9 transition-colors hover:bg-ink-2">
                <div className="font-serif text-sm font-light italic text-copper-soft">{step.n}</div>
                <h3 className="mt-6 font-serif text-2xl font-light">{step.title}</h3>
                <p className="mt-2 text-sm leading-[1.6] text-paper/55">{step.body}</p>
                <span className="mt-6 inline-block text-xs font-semibold uppercase tracking-[0.14em] text-copper-soft group-hover:text-copper">
                  {step.cta} →
                </span>
              </Link>
            ))}
          </div>
        </div>
      </section>

      {/* CATEGORIES — cream section, 1px-gap grid */}
      <section className="section-light relative bg-cream-2 px-6 py-28 md:py-36">
        <div className="ghost-num right-10 top-16">02</div>
        <div className="mx-auto max-w-6xl">
          <div className="reveal">
            <span className="marker">Popular categories</span>
            <h2 className="mt-4 font-serif text-[clamp(40px,6vw,78px)] font-light leading-[1.02] tracking-[-0.015em]">
              Browse by <em className="text-copper">category.</em>
            </h2>
          </div>
          <div className="reveal-stagger mt-14 grid grid-cols-2 gap-px border border-rule bg-rule md:grid-cols-3">
            {BROWSE_CATEGORIES.map((cat) => (
              <Link
                key={cat}
                href={`/models?category=${cat}`}
                className="group bg-cream-2 p-8 transition-colors hover:bg-paper"
              >
                <p className="font-serif text-2xl font-light group-hover:text-copper">{CATEGORY_LABELS[cat]}</p>
                <p className="mt-2 text-xs font-semibold uppercase tracking-[0.22em] text-muted">
                  {categoryCounts.get(cat) ?? 0} models
                </p>
              </Link>
            ))}
          </div>
        </div>
      </section>

      {/* FEATURED — navy section, team-grid style cells */}
      {featuredModels.length > 0 && (
        <section className="bg-ink px-6 py-28 md:py-36">
          <div className="mx-auto max-w-6xl">
            <div className="reveal flex flex-wrap items-end justify-between gap-6">
              <div>
                <span className="marker">New &amp; featured</span>
                <h2 className="mt-4 font-serif text-[clamp(40px,6vw,78px)] font-light leading-[1.02] tracking-[-0.015em]">
                  On the <em className="text-copper-soft">market.</em>
                </h2>
              </div>
              <Link
                href="/models"
                className="text-xs font-semibold uppercase tracking-[0.22em] text-paper/60 hover:text-copper-soft"
              >
                All models →
              </Link>
            </div>
            <ul className="reveal-stagger mt-14 grid gap-px border border-white/10 bg-white/10 sm:grid-cols-2 lg:grid-cols-4">
              {featuredModels.map((model) => (
                <li key={model.id} className="bg-ink transition-colors hover:bg-ink-2">
                  <Link href={`/models/${model.slug}`} className="block">
                    {model.hero_image_url && (
                      <div className="relative aspect-[16/9] overflow-hidden">
                        {model.manufacturers?.status === 'partner' && <VerifiedBadge />}
                        <Image
                          src={model.hero_image_url}
                          alt={`${model.manufacturers?.name} ${model.name}`}
                          fill
                          sizes="(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 25vw"
                          className="object-cover"
                        />
                      </div>
                    )}
                    <div className="p-8">
                      <div className="text-[11px] font-semibold uppercase tracking-[0.28em] text-copper-soft">
                        {model.is_featured ? 'Featured' : model.manufacturers?.name}
                      </div>
                      <h4 className="mt-3 font-serif text-2xl font-light">{model.name}</h4>
                      <p className="mt-3 text-sm text-paper/55">
                        {model.is_featured && `${model.manufacturers?.name} · `}
                        {model.category.replace('_', ' ')}
                      </p>
                      <p className="mt-4 font-serif text-sm italic text-copper-soft">{formatPrice(model)}</p>
                    </div>
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        </section>
      )}

      {/* GUIDES — light section, border-top editorial cards */}
      {latestGuides.length > 0 && (
        <section className="section-light relative bg-paper px-6 py-28 md:py-36">
          <div className="ghost-num left-10 top-16">03</div>
          <div className="mx-auto max-w-6xl">
            <div className="reveal flex flex-wrap items-end justify-between gap-6">
              <div>
                <span className="marker">Latest stories</span>
                <h2 className="mt-4 font-serif text-[clamp(40px,6vw,78px)] font-light leading-[1.02] tracking-[-0.015em]">
                  Guides &amp; <em className="text-copper">insights.</em>
                </h2>
              </div>
              <Link
                href="/guides"
                className="text-xs font-semibold uppercase tracking-[0.22em] text-muted hover:text-copper"
              >
                All guides →
              </Link>
            </div>
            <ul className="reveal-stagger mt-14 grid gap-10 md:grid-cols-3">
              {latestGuides.map((guide) => (
                <li key={guide.id} className="border-t border-rule-strong pt-6">
                  <div className="text-[11px] font-semibold uppercase tracking-[0.28em] text-copper">
                    {CONTENT_TYPE_LABELS[guide.content_page_groups.content_type]}
                  </div>
                  <Link
                    href={`/guides/${guide.slug}`}
                    className="mt-3 block font-serif text-2xl font-light leading-[1.2] hover:text-copper"
                  >
                    {guide.title}
                  </Link>
                  {guide.meta_description && (
                    <p className="mt-3 text-sm leading-[1.6] text-muted">{guide.meta_description}</p>
                  )}
                </li>
              ))}
            </ul>
          </div>
        </section>
      )}

      {/* COMPARE CTA — navy section with ghost word */}
      <section className="relative overflow-hidden bg-ink px-6 py-28 md:py-36">
        <div className="ghost-word -right-10 -top-6">Compare</div>
        <div className="relative z-[2] mx-auto max-w-3xl text-center">
          <span className="marker justify-center">The comparison tool</span>
          <h2 className="mt-4 font-serif text-[clamp(40px,6vw,78px)] font-light leading-[1.02] tracking-[-0.015em]">
            Any models, <em className="text-copper-soft">side by side.</em>
          </h2>
          <p className="mx-auto mt-6 max-w-[44ch] font-serif text-xl font-light leading-[1.4] text-paper/70">
            Compare length, battery, motor power, range, and price across any models in the database.
          </p>
          <Link
            href="/models"
            className="mt-10 inline-block rounded-full bg-copper px-8 py-4 text-xs font-semibold uppercase tracking-[0.25em] text-paper transition-colors hover:bg-copper-soft"
          >
            Start comparing
          </Link>
        </div>
      </section>
    </>
  );
}
