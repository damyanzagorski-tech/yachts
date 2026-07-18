'use client';

import { useEffect } from 'react';

/**
 * Adds the `.in` class to every `.reveal` / `.reveal-stagger` element as
 * it enters the viewport (see globals.css for the animation styles).
 * Renders nothing — mount once on any page that uses reveal sections.
 */
export function ScrollReveal() {
  useEffect(() => {
    const els = document.querySelectorAll('.reveal, .reveal-stagger');
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add('in');
            io.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.15, rootMargin: '0px 0px -8% 0px' }
    );
    els.forEach((el) => io.observe(el));
    return () => io.disconnect();
  }, []);

  return null;
}
