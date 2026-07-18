'use client';

import Image from 'next/image';
import { useState } from 'react';

/**
 * Image gallery for a model detail page: a large stage image with
 * thumbnail switching below (click or hover), in the spirit of the
 * brand reference's hull-colour configurator. Generic — driven by
 * whatever is in the model's gallery_urls; falls back to a single
 * static image when there's only one.
 */
export function ModelGallery({ images, alt }: { images: string[]; alt: string }) {
  const [active, setActive] = useState(0);

  if (images.length === 0) return null;

  return (
    <div>
      <div className="relative aspect-[16/9] overflow-hidden rounded-sm bg-ink-2">
        {images.map((src, i) => (
          <Image
            key={src}
            src={src}
            alt={`${alt} — variant ${i + 1}`}
            fill
            sizes="(max-width: 768px) 100vw, 60vw"
            priority={i === 0}
            className={`object-cover transition-opacity duration-500 ${i === active ? 'opacity-100' : 'opacity-0'}`}
          />
        ))}
      </div>

      {images.length > 1 && (
        <div className="mt-3 grid grid-cols-5 gap-3">
          {images.map((src, i) => (
            <button
              key={src}
              type="button"
              onClick={() => setActive(i)}
              onMouseEnter={() => setActive(i)}
              aria-label={`Show variant ${i + 1}`}
              aria-pressed={i === active}
              className={`relative aspect-[16/9] overflow-hidden rounded-sm transition-all ${
                i === active
                  ? 'ring-2 ring-copper'
                  : 'opacity-60 ring-1 ring-rule hover:opacity-100'
              }`}
            >
              <Image src={src} alt="" fill sizes="120px" className="object-cover" />
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
