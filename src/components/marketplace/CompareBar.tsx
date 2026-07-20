'use client';

import Link from 'next/link';

export const MAX_COMPARE = 4;

export function CompareBar({ selected }: { selected: string[] }) {
  if (selected.length === 0) return null;
  return (
    <div className="fixed inset-x-0 bottom-0 z-30 flex items-center justify-between border-t border-rule bg-background px-6 py-4">
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
  );
}
