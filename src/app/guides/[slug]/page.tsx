import Link from 'next/link';
import { headers } from 'next/headers';
import { notFound } from 'next/navigation';
import { marked } from 'marked';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { buildAlternates } from '@/lib/seo';
import { CONTENT_TYPE_LABELS, type ContentPageWithGroup } from '@/lib/supabase/content';
import type { Manufacturer, Model } from '@/lib/supabase/types';

type PageProps = { params: Promise<{ slug: string }> };

async function getGuide(slug: string, language: string): Promise<ContentPageWithGroup | null> {
  const supabase = createSupabaseServerClient();
  const { data } = await supabase
    .from('content_pages')
    .select('*, content_page_groups(content_type, related_manufacturer_id, related_model_id)')
    .eq('slug', slug)
    .eq('language', language)
    .eq('status', 'published')
    .maybeSingle();
  return data as unknown as ContentPageWithGroup | null;
}

async function getRelatedLinks(group: ContentPageWithGroup['content_page_groups']) {
  const supabase = createSupabaseServerClient();
  const links: { href: string; label: string }[] = [];

  if (group.related_manufacturer_id) {
    const { data } = await supabase
      .from('manufacturers')
      .select('name, slug')
      .eq('id', group.related_manufacturer_id)
      .maybeSingle<Pick<Manufacturer, 'name' | 'slug'>>();
    if (data) links.push({ href: `/manufacturers/${data.slug}`, label: data.name });
  }

  if (group.related_model_id) {
    const { data } = await supabase
      .from('models')
      .select('name, slug')
      .eq('id', group.related_model_id)
      .maybeSingle<Pick<Model, 'name' | 'slug'>>();
    if (data) links.push({ href: `/models/${data.slug}`, label: data.name });
  }

  return links;
}

export async function generateMetadata({ params }: PageProps) {
  const { slug } = await params;
  const requestHeaders = await headers();
  const language = requestHeaders.get('x-market-language') ?? 'en';
  const guide = await getGuide(slug, language);

  return {
    title: guide ? `${guide.title} — Electric Yachts` : 'Guide',
    description: guide?.meta_description ?? undefined,
    alternates: await buildAlternates(`/guides/${slug}`),
  };
}

export default async function GuideDetailPage({ params }: PageProps) {
  const { slug } = await params;
  const requestHeaders = await headers();
  const language = requestHeaders.get('x-market-language') ?? 'en';
  const guide = await getGuide(slug, language);
  if (!guide) notFound();

  const relatedLinks = await getRelatedLinks(guide.content_page_groups);
  const bodyHtml = guide.body_markdown ? await marked.parse(guide.body_markdown) : '';

  return (
    <main className="mx-auto max-w-2xl px-6 py-16">
      <Link href="/guides" className="text-sm text-zinc-600 hover:underline dark:text-zinc-400">
        ← All guides
      </Link>

      <p className="mt-4 text-xs font-medium uppercase tracking-wide text-zinc-500 dark:text-zinc-400">
        {CONTENT_TYPE_LABELS[guide.content_page_groups.content_type]}
      </p>
      <h1 className="mt-1 text-2xl font-semibold tracking-tight">{guide.title}</h1>
      {guide.meta_description && (
        <p className="mt-3 text-lg text-zinc-600 dark:text-zinc-400">{guide.meta_description}</p>
      )}

      <div className="markdown-body mt-8" dangerouslySetInnerHTML={{ __html: bodyHtml }} />

      {relatedLinks.length > 0 && (
        <div className="mt-8 flex flex-wrap gap-3 border-t border-black/[.08] pt-6 dark:border-white/[.145]">
          {relatedLinks.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              className="rounded-full border border-black/[.08] px-4 py-2 text-sm hover:bg-black/[.04] dark:border-white/[.145] dark:hover:bg-[#1a1a1a]"
            >
              {link.label} →
            </Link>
          ))}
        </div>
      )}
    </main>
  );
}
