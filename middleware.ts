import { NextRequest, NextResponse } from 'next/server';
import { resolveMarket } from './domains.config';

/**
 * Resolves the incoming domain to a market (language/country), then
 * forwards that info to the page via a request header so server
 * components can read it without re-parsing the Host header themselves.
 *
 * Usage in a page/layout:
 *   const market = headers().get('x-market-language'); // e.g. "de"
 *   const country = headers().get('x-market-country');  // e.g. "Germany"
 *
 * If the domain isn't in domains.config.ts, we fall back to the primary
 * (English) market rather than erroring — safer default for any domain
 * that gets pointed here before its config entry is added.
 */
export function middleware(request: NextRequest) {
  const host = request.headers.get('host') ?? '';
  const market = resolveMarket(host);

  const requestHeaders = new Headers(request.headers);
  requestHeaders.set('x-market-language', market?.language ?? 'en');
  requestHeaders.set('x-market-country', market?.country ?? '');
  requestHeaders.set('x-market-hreflang', market?.hreflang ?? 'en');

  return NextResponse.next({
    request: { headers: requestHeaders },
  });
}

export const config = {
  // Run on every page request, skip static assets/api internals
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'],
};
