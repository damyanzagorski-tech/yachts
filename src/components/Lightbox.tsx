'use client';

import Image from 'next/image';
import { useEffect } from 'react';

/**
 * Full-screen image lightbox in the site's navy editorial style.
 * Controlled: `index` is the image currently shown (null = closed).
 * Esc closes; arrow keys / on-screen arrows navigate; backdrop click
 * closes. Page scroll is locked while open.
 */
export function Lightbox({
  images,
  alt,
  index,
  onClose,
  onIndexChange,
}: {
  images: string[];
  alt: string;
  index: number | null;
  onClose: () => void;
  onIndexChange: (index: number) => void;
}) {
  const open = index !== null;

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
      if (e.key === 'ArrowRight') onIndexChange(((index ?? 0) + 1) % images.length);
      if (e.key === 'ArrowLeft') onIndexChange(((index ?? 0) - 1 + images.length) % images.length);
    };
    window.addEventListener('keydown', onKey);
    document.documentElement.style.overflow = 'hidden';
    return () => {
      window.removeEventListener('keydown', onKey);
      document.documentElement.style.overflow = '';
    };
  }, [open, index, images.length, onClose, onIndexChange]);

  if (index === null) return null;

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-label={`${alt} — image ${index + 1} of ${images.length}`}
      className="fixed inset-0 z-[100] flex items-center justify-center bg-ink/95 backdrop-blur-sm"
      onClick={onClose}
    >
      <div className="relative h-[82vh] w-[92vw]" onClick={(e) => e.stopPropagation()}>
        <Image
          src={images[index]}
          alt={`${alt} — image ${index + 1} of ${images.length}`}
          fill
          sizes="92vw"
          priority
          className="object-contain"
        />
      </div>

      <button
        type="button"
        onClick={onClose}
        aria-label="Close gallery"
        className="absolute right-5 top-4 font-serif text-4xl font-light text-paper/70 transition-colors hover:text-copper-soft"
      >
        ×
      </button>

      {images.length > 1 && (
        <>
          <button
            type="button"
            onClick={(e) => {
              e.stopPropagation();
              onIndexChange((index - 1 + images.length) % images.length);
            }}
            aria-label="Previous image"
            className="absolute left-3 top-1/2 -translate-y-1/2 px-3 py-6 font-serif text-5xl font-light text-paper/70 transition-colors hover:text-copper-soft sm:left-6"
          >
            ‹
          </button>
          <button
            type="button"
            onClick={(e) => {
              e.stopPropagation();
              onIndexChange((index + 1) % images.length);
            }}
            aria-label="Next image"
            className="absolute right-3 top-1/2 -translate-y-1/2 px-3 py-6 font-serif text-5xl font-light text-paper/70 transition-colors hover:text-copper-soft sm:right-6"
          >
            ›
          </button>
        </>
      )}

      <div className="absolute bottom-5 left-1/2 -translate-x-1/2 text-xs font-semibold uppercase tracking-[0.25em] text-paper/60">
        {index + 1} / {images.length}
      </div>
    </div>
  );
}
