'use client';

import Image from 'next/image';
import { useState } from 'react';
import { Lightbox } from '@/components/Lightbox';

/**
 * Full-width lifestyle/detail gallery for a model detail page: the
 * first image renders as a wide cinematic lead, the rest in a two-
 * column grid. Every image opens the full-screen lightbox, browsable
 * across the whole set.
 */
export function ModelLifestyleGallery({ images, alt }: { images: string[]; alt: string }) {
  const [lightboxIndex, setLightboxIndex] = useState<number | null>(null);

  if (images.length === 0) return null;

  return (
    <div className="grid gap-4">
      <button
        type="button"
        onClick={() => setLightboxIndex(0)}
        aria-label={`Open gallery image 1 of ${images.length}`}
        className="group relative block aspect-[21/9] cursor-zoom-in overflow-hidden rounded-sm bg-ink-2"
      >
        <Image
          src={images[0]}
          alt={`${alt} — gallery image 1`}
          fill
          sizes="(max-width: 1152px) 100vw, 1152px"
          className="object-cover transition-transform duration-700 group-hover:scale-[1.02]"
        />
      </button>

      {images.length > 1 && (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          {images.slice(1).map((src, i) => (
            <button
              key={src}
              type="button"
              onClick={() => setLightboxIndex(i + 1)}
              aria-label={`Open gallery image ${i + 2} of ${images.length}`}
              className="group relative block aspect-[16/9] cursor-zoom-in overflow-hidden rounded-sm bg-ink-2"
            >
              <Image
                src={src}
                alt={`${alt} — gallery image ${i + 2}`}
                fill
                sizes="(max-width: 640px) 100vw, 50vw"
                className="object-cover transition-transform duration-700 group-hover:scale-[1.02]"
              />
            </button>
          ))}
        </div>
      )}

      <Lightbox
        images={images}
        alt={alt}
        index={lightboxIndex}
        onClose={() => setLightboxIndex(null)}
        onIndexChange={setLightboxIndex}
      />
    </div>
  );
}
