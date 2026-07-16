/**
 * Domain-to-market mapping for electroyachts.com and its multi-domain
 * portfolio. Read by middleware.ts on every request (via the Host header)
 * to resolve which language/country content_pages rows to serve.
 *
 * IMPORTANT: manufacturers/models data is IDENTICAL across every domain.
 * Only `content_pages.language` differs. Do not filter manufacturers/models
 * by domain — only content_pages and any future country-specific SEO logic.
 *
 * hreflang: every entry's `hreflang` value must be unique across the list
 * and match the `language`/`country` combination used when querying
 * content_pages (e.g. hreflang "de-DE" <-> content_pages.language = 'de'
 * AND content_pages.country = 'Germany', if country-scoping is used).
 */

export type MarketConfig = {
  domain: string;
  language: string;       // ISO 639-1, matches content_pages.language
  country: string | null; // matches content_pages.country, null = language-only (no country scoping)
  hreflang: string;       // BCP 47 tag for the <link rel="alternate" hreflang="..."> tag
  isPrimary: boolean;     // true for the one domain being built first as the template
  status: 'live' | 'planned' | 'phase-1'; // phase-1 = confirmed as first-wave per user
};

export const DOMAIN_MARKETS: MarketConfig[] = [
  // ---- Global / umbrella brand (English) ----
  // NOTE: pick ONE of these as canonical before launch; the others should
  // 301-redirect to it rather than serve duplicate content.
  { domain: 'electricyachtmarket.com',    language: 'en', country: null,      hreflang: 'en',    isPrimary: true,  status: 'live' },
  { domain: 'electricyachts.co.uk',       language: 'en', country: 'United Kingdom', hreflang: 'en-GB', isPrimary: false, status: 'planned' },

  // ---- Phase 1: "Electric Yachts" language-specific domains ----
  { domain: 'elektrickejachty.cz',   language: 'cs', country: 'Czechia',      hreflang: 'cs-CZ', isPrimary: false, status: 'phase-1' },
  { domain: 'elektrickejachty.sk',   language: 'sk', country: 'Slovakia',     hreflang: 'sk-SK', isPrimary: false, status: 'phase-1' },
  { domain: 'elektricnejahte.com',   language: 'hr', country: null,          hreflang: 'hr',    isPrimary: false, status: 'phase-1' }, // covers HR/RS/SI/BA shared language, no single ccTLD purchased
  { domain: 'elektrischejachten.nl', language: 'nl', country: 'Netherlands', hreflang: 'nl-NL', isPrimary: false, status: 'phase-1' },
  { domain: 'elektrischeyachten.de', language: 'de', country: 'Germany',     hreflang: 'de-DE', isPrimary: false, status: 'phase-1' },
  { domain: 'elektrischeyachten.ch', language: 'de', country: 'Switzerland', hreflang: 'de-CH', isPrimary: false, status: 'phase-1' },
  { domain: 'elektriskayachter.se',  language: 'sv', country: 'Sweden',      hreflang: 'sv-SE', isPrimary: false, status: 'phase-1' },
  { domain: 'elektriskeyachter.dk',  language: 'da', country: 'Denmark',     hreflang: 'da-DK', isPrimary: false, status: 'phase-1' },
  { domain: 'iahturielectrice.ro',   language: 'ro', country: 'Romania',     hreflang: 'ro-RO', isPrimary: false, status: 'phase-1' },
  { domain: 'jachtyelektryczne.pl',  language: 'pl', country: 'Poland',      hreflang: 'pl-PL', isPrimary: false, status: 'phase-1' },
  { domain: 'yachtelettrici.it',     language: 'it', country: 'Italy',       hreflang: 'it-IT', isPrimary: false, status: 'phase-1' },
  { domain: 'yachtelettrici.ch',     language: 'it', country: 'Switzerland', hreflang: 'it-CH', isPrimary: false, status: 'phase-1' },
  { domain: 'yachtselectriques.fr',  language: 'fr', country: 'France',      hreflang: 'fr-FR', isPrimary: false, status: 'phase-1' },
  { domain: 'yachtselectriques.ch',  language: 'fr', country: 'Switzerland', hreflang: 'fr-CH', isPrimary: false, status: 'phase-1' },
  { domain: 'yateselectricos.es',    language: 'es', country: 'Spain',      hreflang: 'es-ES', isPrimary: false, status: 'phase-1' },
];

/** Convenience lookup used by middleware.ts */
export function resolveMarket(host: string): MarketConfig | undefined {
  const cleanHost = host.replace(/^www\./, '').toLowerCase();
  return DOMAIN_MARKETS.find((m) => m.domain === cleanHost);
}

/** The domain currently being built out fully before replicating to others */
export const PRIMARY_DOMAIN = DOMAIN_MARKETS.find((m) => m.isPrimary)!;
