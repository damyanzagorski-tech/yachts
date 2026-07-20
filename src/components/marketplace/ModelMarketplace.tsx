'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import { EQUIPMENT_LABELS } from '@/lib/marketplace/equipment';
import {
  applyFilters,
  countActiveFilters,
  EMPTY_FILTERS,
  KEEL_LABELS,
  PROPULSION_LABELS,
  serializeFilters,
  type FilterState,
  type MarketplaceModel,
  type NumRange,
} from '@/lib/marketplace/filters';
import { CATEGORY_LABELS, type BoatCategory, type PropulsionType } from '@/lib/supabase/types';
import { CompareBar, MAX_COMPARE } from './CompareBar';
import { FilterSidebar, type FacetContext } from './FilterSidebar';
import { ModelCard } from './ModelCard';

type Chip = { key: string; label: string; onRemove: () => void };

export function ModelMarketplace({
  models,
  initialFilters,
}: {
  models: MarketplaceModel[];
  initialFilters: FilterState;
}) {
  const [filters, setFilters] = useState<FilterState>(initialFilters);
  const [selected, setSelected] = useState<string[]>([]);
  const [mobileOpen, setMobileOpen] = useState(false);
  const isFirstRender = useRef(true);

  // Keep the URL shareable without triggering RSC refetches.
  useEffect(() => {
    if (isFirstRender.current) {
      isFirstRender.current = false;
      return;
    }
    window.history.replaceState(null, '', window.location.pathname + serializeFilters(filters));
  }, [filters]);

  const filtered = useMemo(() => applyFilters(models, filters), [models, filters]);

  // Facet counts per group are computed against the dataset filtered by all
  // OTHER groups (standard faceted-search behavior).
  const contextFor: FacetContext = useMemo(() => {
    const cache = new Map<string, MarketplaceModel[]>();
    return (group) => {
      const hit = cache.get(group);
      if (hit) return hit;
      const cleared: FilterState = { ...filters };
      if (group === 'q') cleared.q = '';
      else if (
        group === 'categories' ||
        group === 'brands' ||
        group === 'propulsion' ||
        group === 'equipment' ||
        group === 'keel'
      ) {
        (cleared[group] as string[]) = [];
      } else if (group === 'engines') cleared.engines = [];
      else (cleared[group] as NumRange) = { min: null, max: null };
      const result = applyFilters(models, cleared);
      cache.set(group, result);
      return result;
    };
  }, [models, filters]);

  const activeCount = countActiveFilters(filters);

  function toggleCompare(slug: string) {
    setSelected((prev) =>
      prev.includes(slug) ? prev.filter((s) => s !== slug) : prev.length < MAX_COMPARE ? [...prev, slug] : prev,
    );
  }

  const chips: Chip[] = useMemo(() => {
    const list: Chip[] = [];
    const brandNames: Record<string, string> = {};
    for (const m of models) {
      if (m.manufacturers?.slug) brandNames[m.manufacturers.slug] = m.manufacturers.name;
    }
    if (filters.q.trim()) {
      list.push({ key: 'q', label: `“${filters.q.trim()}”`, onRemove: () => setFilters((f) => ({ ...f, q: '' })) });
    }
    for (const c of filters.categories) {
      list.push({
        key: `cat-${c}`,
        label: CATEGORY_LABELS[c as BoatCategory] ?? c,
        onRemove: () => setFilters((f) => ({ ...f, categories: f.categories.filter((v) => v !== c) })),
      });
    }
    for (const b of filters.brands) {
      list.push({
        key: `brand-${b}`,
        label: brandNames[b] ?? b,
        onRemove: () => setFilters((f) => ({ ...f, brands: f.brands.filter((v) => v !== b) })),
      });
    }
    for (const p of filters.propulsion) {
      list.push({
        key: `fuel-${p}`,
        label: PROPULSION_LABELS[p as PropulsionType] ?? p,
        onRemove: () => setFilters((f) => ({ ...f, propulsion: f.propulsion.filter((v) => v !== p) })),
      });
    }
    for (const n of filters.engines) {
      list.push({
        key: `eng-${n}`,
        label: n === 1 ? '1 motor' : `${n} motors`,
        onRemove: () => setFilters((f) => ({ ...f, engines: f.engines.filter((v) => v !== n) })),
      });
    }
    for (const e of filters.equipment) {
      list.push({
        key: `eq-${e}`,
        label: EQUIPMENT_LABELS[e] ?? e,
        onRemove: () => setFilters((f) => ({ ...f, equipment: f.equipment.filter((v) => v !== e) })),
      });
    }
    for (const k of filters.keel) {
      list.push({
        key: `keel-${k}`,
        label: KEEL_LABELS[k] ?? k,
        onRemove: () => setFilters((f) => ({ ...f, keel: f.keel.filter((v) => v !== k) })),
      });
    }
    const rangeChip = (
      key: 'price' | 'length' | 'beam' | 'draft' | 'airDraft' | 'range' | 'power' | 'cabins' | 'berths',
      name: string,
      unit: string,
    ) => {
      const r = filters[key];
      if (r.min === null && r.max === null) return;
      const label =
        r.min !== null && r.max !== null
          ? `${name} ${r.min}–${r.max}${unit}`
          : r.min !== null
            ? `${name} ≥ ${r.min}${unit}`
            : `${name} ≤ ${r.max}${unit}`;
      list.push({
        key,
        label,
        onRemove: () => setFilters((f) => ({ ...f, [key]: { min: null, max: null } })),
      });
    };
    rangeChip('price', 'Price', ' €');
    rangeChip('length', 'Length', ' m');
    rangeChip('beam', 'Beam', ' m');
    rangeChip('draft', 'Draught', ' m');
    rangeChip('airDraft', 'Air draught', ' m');
    rangeChip('range', 'Range', ' nm');
    rangeChip('power', 'Power', ' kW');
    rangeChip('cabins', 'Cabins', '');
    rangeChip('berths', 'Berths', '');
    return list;
  }, [filters, models]);

  const sidebar = (
    <FilterSidebar models={models} filters={filters} contextFor={contextFor} onChange={setFilters} />
  );

  return (
    <div className="mt-10 grid gap-10 lg:grid-cols-[280px_1fr]">
      <aside className="hidden lg:block">{sidebar}</aside>

      <div>
        <div className="flex flex-wrap items-center gap-3 border-b border-rule pb-4">
          <p className="font-serif text-lg font-light italic text-copper">
            {filtered.length} {filtered.length === 1 ? 'result' : 'results'}
          </p>
          <div className="flex flex-1 flex-wrap items-center gap-2">
            {chips.map((chip) => (
              <button
                key={chip.key}
                type="button"
                onClick={chip.onRemove}
                className="group flex items-center gap-1.5 rounded-full border border-rule bg-ink-2 px-3 py-1 text-xs text-paper/85 transition-colors hover:border-copper"
              >
                {chip.label}
                <span className="text-muted group-hover:text-copper">×</span>
              </button>
            ))}
            {activeCount > 0 && (
              <button
                type="button"
                onClick={() => setFilters(EMPTY_FILTERS)}
                className="text-xs font-semibold uppercase tracking-[0.16em] text-muted transition-colors hover:text-copper"
              >
                Clear all
              </button>
            )}
          </div>
          <button
            type="button"
            onClick={() => setMobileOpen(true)}
            className="rounded-full border border-rule px-4 py-1.5 text-xs font-semibold uppercase tracking-[0.16em] text-paper transition-colors hover:border-copper lg:hidden"
          >
            Filters{activeCount > 0 && ` (${activeCount})`}
          </button>
        </div>

        {filtered.length === 0 ? (
          <p className="mt-8 text-muted">No models match these filters.</p>
        ) : (
          <ul className="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-3">
            {filtered.map((model) => (
              <ModelCard
                key={model.id}
                model={model}
                checked={selected.includes(model.slug)}
                compareDisabled={!selected.includes(model.slug) && selected.length >= MAX_COMPARE}
                onToggleCompare={() => toggleCompare(model.slug)}
              />
            ))}
          </ul>
        )}
      </div>

      {mobileOpen && (
        <div className="fixed inset-0 z-40 lg:hidden" role="dialog" aria-modal="true" aria-label="Filters">
          <div className="absolute inset-0 bg-ink/95" onClick={() => setMobileOpen(false)} />
          <div className="absolute inset-y-0 left-0 flex w-[85%] max-w-sm flex-col bg-ink-2 shadow-2xl">
            <div className="flex items-center justify-between border-b border-rule px-5 py-4">
              <span className="text-xs font-semibold uppercase tracking-[0.16em] text-muted">Filters</span>
              <button
                type="button"
                onClick={() => setMobileOpen(false)}
                className="text-2xl leading-none text-paper hover:text-copper"
                aria-label="Close filters"
              >
                ×
              </button>
            </div>
            <div className="flex-1 overflow-y-auto px-5 pb-24">{sidebar}</div>
            <div className="border-t border-rule bg-ink-2 px-5 py-4">
              <button
                type="button"
                onClick={() => setMobileOpen(false)}
                className="w-full rounded-full bg-copper px-5 py-2.5 text-sm font-semibold uppercase tracking-[0.1em] text-paper transition-colors hover:bg-copper-soft"
              >
                Show {filtered.length} {filtered.length === 1 ? 'result' : 'results'}
              </button>
            </div>
          </div>
        </div>
      )}

      <CompareBar selected={selected} />
    </div>
  );
}
