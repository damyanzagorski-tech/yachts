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

async function getGuides(language: string): Promise<ContentPageWithGroup[]> {
  const supabase = createSupabaseServerClient();
  const { data } = await supabase
    .from('content_pages')
    .select('*, content_page_groups(content_type, related_manufacturer_id, related_model_id)')
    .eq('language', language)
    .eq('status', 'published')
    .order('published_at', { ascending: false });
  return (data as unknown as ContentPageWithGroup[]) ?? [];
}

export default async function GuidesPage() {
  const requestHeaders = await headers();
  const language = requestHeaders.get('x-market-language') ?? 'en';
  const guides = await getGuides(language);

  return (
    <main className="mx-auto max-w-4xl px-6 py-16">
      <span className="marker">Editorial</span>
      <h1 className="mt-3 mb-8 font-serif text-3xl font-light tracking-tight">Guides</h1>

      {guides.length === 0 && <p className="text-ink-soft">No guides published yet.</p>}

      <ul className="flex flex-col gap-4">
        {guides.map((guide) => (
          <li key={guide.id} className="rounded-lg border border-rule p-5 transition-colors hover:border-copper">
            <span className="badge">{CONTENT_TYPE_LABELS[guide.content_page_groups.content_type]}</span>
            <Link href={`/guides/${guide.slug}`} className="mt-2 block font-serif text-lg hover:text-copper">
              {guide.title}
            </Link>
            {guide.meta_description && <p className="mt-1 text-sm text-ink-soft">{guide.meta_description}</p>}
          </li>
        ))}
      </ul>
    </main>
  );
}
