'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';

/**
 * Fixed top navigation, per the brand reference: transparent with a
 * navy scrim while sitting over the hero, switching to a blurred cream
 * bar with ink text once the page scrolls past 80px.
 */
export function SiteNav() {
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 80);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  const linkClass = scrolled
    ? 'text-ink/70 transition-colors hover:text-copper'
    : 'text-paper/70 transition-colors hover:text-copper-soft';

  return (
    <header
      className={`fixed inset-x-0 top-0 z-50 transition-all duration-300 ${
        scrolled
          ? 'border-b border-[rgba(11,26,44,0.15)] bg-cream/90 py-3 text-ink backdrop-blur-md'
          : 'nav-scrim py-5 text-paper'
      }`}
    >
      <nav className="mx-auto grid max-w-6xl grid-cols-[1fr_auto] items-center gap-8 px-6 sm:grid-cols-[1fr_auto_1fr]">
        <Link href="/" className="justify-self-start whitespace-nowrap font-serif text-base font-light tracking-[0.1em]">
          Electric <em className={scrolled ? 'text-copper' : 'text-copper-soft'}>Yacht</em> Market
        </Link>
        <div className="hidden items-center gap-9 text-xs font-semibold uppercase tracking-[0.22em] sm:flex">
          <Link href="/manufacturers" className={linkClass}>
            Manufacturers
          </Link>
          <Link href="/models" className={linkClass}>
            Models
          </Link>
          <Link href="/guides" className={linkClass}>
            Guides
          </Link>
        </div>
        <Link
          href="/models"
          className={`justify-self-end rounded-full border px-5 py-2.5 text-xs font-semibold uppercase tracking-[0.22em] transition-colors hover:border-copper hover:bg-copper hover:text-paper ${
            scrolled ? 'border-ink/40' : 'border-paper/50'
          }`}
        >
          Compare
        </Link>
      </nav>
    </header>
  );
}
