import { DOMAIN_MARKETS } from './domains.config';

/**
 * Renders <link rel="alternate" hreflang="..."> tags for every domain
 * that has an equivalent version of the current page.
 *
 * MUST be included in every page's <head> once multiple domains are live.
 * This is what prevents Google from treating electroyachts.de and
 * electroyachts.fr (etc.) as duplicate content of each other, since the
 * underlying manufacturer/model data is identical across all of them.
 *
 * `pathname` should be the market-agnostic path, e.g. "/models/candela-c-8"
 * — the same path structure is assumed to exist on every domain.
 */
export function HreflangTags({ pathname }: { pathname: string }) {
  return (
    <>
      {DOMAIN_MARKETS.map((market) => (
        <link
          key={market.domain}
          rel="alternate"
          hrefLang={market.hreflang}
          href={`https://${market.domain}${pathname}`}
        />
      ))}
      {/* x-default: fallback for languages/regions not explicitly listed */}
      <link
        rel="alternate"
        hrefLang="x-default"
        href={`https://electricyachtmarket.com${pathname}`}
      />
    </>
  );
}

/**
 * Canonical tag — set to the CURRENT domain's own URL, never another
 * domain's. Combined with hreflang tags above, this tells Google
 * "these are translations of each other, not duplicates."
 */
export function CanonicalTag({ domain, pathname }: { domain: string; pathname: string }) {
  return <link rel="canonical" href={`https://${domain}${pathname}`} />;
}
