'use client';

import { useEffect, useRef, useState } from 'react';
import type { NumRange } from '@/lib/marketplace/filters';

export function FilterSection({
  title,
  children,
  defaultOpen = true,
}: {
  title: string;
  children: React.ReactNode;
  defaultOpen?: boolean;
}) {
  const [open, setOpen] = useState(defaultOpen);
  return (
    <section className="border-b border-rule py-4">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        className="flex w-full items-center justify-between text-left"
      >
        <span className="text-xs font-semibold uppercase tracking-[0.16em] text-muted">{title}</span>
        <span className={`text-copper transition-transform ${open ? 'rotate-180' : ''}`} aria-hidden>
          ⌄
        </span>
      </button>
      {open && <div className="mt-3 space-y-2">{children}</div>}
    </section>
  );
}

export function SearchField({
  value,
  onChange,
  placeholder,
}: {
  value: string;
  onChange: (v: string) => void;
  placeholder: string;
}) {
  return (
    <input
      type="search"
      value={value}
      onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder}
      className="w-full rounded-md border border-rule bg-ink-2 px-3 py-2 text-sm text-paper placeholder:text-muted focus:border-copper focus:outline-none"
    />
  );
}

export type FacetOption = { value: string; label: string; count: number };

export function CheckboxFacet({
  options,
  selected,
  onToggle,
}: {
  options: FacetOption[];
  selected: string[];
  onToggle: (value: string) => void;
}) {
  return (
    <ul className="max-h-56 space-y-1.5 overflow-y-auto pr-1">
      {options.map((opt) => (
        <li key={opt.value}>
          <label className="flex cursor-pointer items-center gap-2.5 text-sm text-paper/85 hover:text-paper">
            <input
              type="checkbox"
              checked={selected.includes(opt.value)}
              onChange={() => onToggle(opt.value)}
              className="accent-copper"
            />
            <span className="flex-1">{opt.label}</span>
            <span className="text-xs text-muted">{opt.count}</span>
          </label>
        </li>
      ))}
    </ul>
  );
}

/** Min/max numeric inputs, committed to filter state after a 250ms debounce. */
export function RangeField({
  value,
  onChange,
  minPlaceholder,
  maxPlaceholder,
  unit,
  step,
}: {
  value: NumRange;
  onChange: (r: NumRange) => void;
  minPlaceholder?: string;
  maxPlaceholder?: string;
  unit?: string;
  step?: number;
}) {
  const [minText, setMinText] = useState(value.min?.toString() ?? '');
  const [maxText, setMaxText] = useState(value.max?.toString() ?? '');
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const onChangeRef = useRef(onChange);
  useEffect(() => {
    onChangeRef.current = onChange;
  });

  // Sync down when filters are cleared/replaced externally (chips, Clear all) —
  // "adjust state when props change" render-time pattern, not an effect.
  const [prevValue, setPrevValue] = useState(value);
  if (prevValue.min !== value.min || prevValue.max !== value.max) {
    setPrevValue(value);
    setMinText(value.min?.toString() ?? '');
    setMaxText(value.max?.toString() ?? '');
  }

  function commit(minT: string, maxT: string) {
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(() => {
      const parse = (t: string) => {
        if (t.trim() === '') return null;
        const n = Number(t);
        return Number.isFinite(n) ? n : null;
      };
      onChangeRef.current({ min: parse(minT), max: parse(maxT) });
    }, 250);
  }

  const inputClass =
    'w-full rounded-md border border-rule bg-ink-2 px-2.5 py-1.5 text-sm text-paper placeholder:text-muted focus:border-copper focus:outline-none';

  return (
    <div className="flex items-center gap-2">
      <input
        type="number"
        inputMode="decimal"
        step={step}
        value={minText}
        placeholder={minPlaceholder ?? 'Min'}
        onChange={(e) => {
          setMinText(e.target.value);
          commit(e.target.value, maxText);
        }}
        className={inputClass}
        aria-label={`Minimum${unit ? ` (${unit})` : ''}`}
      />
      <span className="text-muted">–</span>
      <input
        type="number"
        inputMode="decimal"
        step={step}
        value={maxText}
        placeholder={maxPlaceholder ?? 'Max'}
        onChange={(e) => {
          setMaxText(e.target.value);
          commit(minText, e.target.value);
        }}
        className={inputClass}
        aria-label={`Maximum${unit ? ` (${unit})` : ''}`}
      />
      {unit && <span className="text-xs text-muted">{unit}</span>}
    </div>
  );
}
