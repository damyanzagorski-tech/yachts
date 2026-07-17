import { headers } from 'next/headers';
import type { Metadata } from 'next';
import { DOMAIN_MARKETS, PRIMARY_DOMAIN } from '@/lib/domains.config';

/**
 * Builds the `alternates` field of a page's Metadata: a canonical tag
 * pointing at the CURRENT domain, plus hreflang links to every other LIVE
 * domain serving the equivalent path. Only 'live' domains are included —
 * linking hreflang to a domain that isn't actually deployed yet would tell
 * search engines a page exists where it doesn't (404).
 *
 * `path` should include a leading slash, and a query string too if the
 * page's content varies meaningfully by search params (e.g. /compare).
 */
export async function buildAlternates(path: string): Promise<Metadata['alternates']> {
  const requestHeaders = await headers();
  const currentHost = (requestHeaders.get('host') ?? PRIMARY_DOMAIN.domain).replace(/^www\./, '');

  const liveMarkets = DOMAIN_MARKETS.filter((m) => m.status === 'live');

  const languages: Record<string, string> = {};
  for (const market of liveMarkets) {
    languages[market.hreflang] = `https://${market.domain}${path}`;
  }
  languages['x-default'] = `https://${PRIMARY_DOMAIN.domain}${path}`;

  return {
    canonical: `https://${currentHost}${path}`,
    languages,
  };
}
