'use client';

import Link from 'next/link';
import { useState } from 'react';
import type { ModelWithManufacturer } from '@/lib/supabase/types';

const MAX_COMPARE = 4;

const eurFormatter = new Intl.NumberFormat('en-EU', {
  style: 'currency',
  currency: 'EUR',
  maximumFractionDigits: 0,
});

function formatPrice(model: ModelWithManufacturer): string {
  return model.price_from_eur ? `From ${eurFormatter.format(model.price_from_eur)}` : 'Price on request';
}

export function ModelCompareList({ models }: { models: ModelWithManufacturer[] }) {
  const [selected, setSelected] = useState<string[]>([]);

  function toggle(slug: string) {
    setSelected((prev) =>
      prev.includes(slug) ? prev.filter((s) => s !== slug) : prev.length < MAX_COMPARE ? [...prev, slug] : prev
    );
  }

  return (
    <>
      <ul className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        {models.map((model) => {
          const checked = selected.includes(model.slug);
          return (
            <li
              key={model.id}
              className="flex items-start gap-3 rounded-lg border border-rule bg-ink-2 p-5 transition-colors hover:border-copper"
            >
              <input
                type="checkbox"
                checked={checked}
                onChange={() => toggle(model.slug)}
                disabled={!checked && selected.length >= MAX_COMPARE}
                aria-label={`Select ${model.name} to compare`}
                className="mt-1.5 accent-copper"
              />
              <div>
                <Link href={`/models/${model.slug}`} className="font-serif text-lg hover:text-copper">
                  {model.name}
                </Link>
                <p className="mt-1 text-xs font-semibold uppercase tracking-[0.16em] text-muted">
                  {model.manufacturers?.name} · {model.category.replace('_', ' ')}
                </p>
                <p className="mt-2 font-serif text-sm italic text-copper">{formatPrice(model)}</p>
              </div>
            </li>
          );
        })}
      </ul>

      {selected.length > 0 && (
        <div className="fixed inset-x-0 bottom-0 flex items-center justify-between border-t border-rule bg-background px-6 py-4">
          <p className="text-xs font-semibold uppercase tracking-[0.16em] text-muted">
            {selected.length} selected{selected.length >= MAX_COMPARE && ` (max ${MAX_COMPARE})`}
          </p>
          <Link
            href={selected.length >= 2 ? `/compare?slugs=${selected.join(',')}` : '#'}
            aria-disabled={selected.length < 2}
            className={
              selected.length >= 2
                ? 'rounded-full bg-copper px-5 py-2 text-sm font-semibold uppercase tracking-[0.1em] text-paper transition-colors hover:bg-copper-soft'
                : 'cursor-not-allowed rounded-full bg-ink-soft px-5 py-2 text-sm font-semibold uppercase tracking-[0.1em] text-muted'
            }
          >
            Compare {selected.length >= 2 ? `(${selected.length})` : ''}
          </Link>
        </div>
      )}
    </>
  );
}
