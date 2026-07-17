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
      <h1 className="mb-8 text-2xl font-semibold tracking-tight">Guides</h1>

      {guides.length === 0 && <p className="text-zinc-600 dark:text-zinc-400">No guides published yet.</p>}

      <ul className="flex flex-col gap-4">
        {guides.map((guide) => (
          <li key={guide.id} className="rounded-lg border border-black/[.08] p-4 dark:border-white/[.145]">
            <p className="text-xs font-medium uppercase tracking-wide text-zinc-500 dark:text-zinc-400">
              {CONTENT_TYPE_LABELS[guide.content_page_groups.content_type]}
            </p>
            <Link href={`/guides/${guide.slug}`} className="mt-1 block text-lg font-medium hover:underline">
              {guide.title}
            </Link>
            {guide.meta_description && (
              <p className="mt-1 text-sm text-zinc-600 dark:text-zinc-400">{guide.meta_description}</p>
            )}
          </li>
        ))}
      </ul>
    </main>
  );
}
