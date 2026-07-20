'use client';

import { EQUIPMENT_GROUPS } from '@/lib/marketplace/equipment';
import {
  KEEL_LABELS,
  PROPULSION_LABELS,
  type FilterState,
  type MarketplaceModel,
  type NumRange,
} from '@/lib/marketplace/filters';
import { CATEGORY_LABELS, type BoatCategory, type PropulsionType } from '@/lib/supabase/types';
import { CheckboxFacet, FilterSection, RangeField, SearchField, type FacetOption } from './FilterControls';

/**
 * Contextual facet counts: each checkbox group's counts are computed against
 * the dataset filtered by every OTHER group (standard faceted-search
 * convention). `contextFor(group)` provides that pre-filtered list.
 * Visibility uses the FULL dataset: options nobody has are hidden entirely
 * (the ">=1 record" rule), groups with no visible options disappear.
 */
export type FacetContext = (group: keyof FilterState) => MarketplaceModel[];

function buildOptions<T extends string>(
  all: MarketplaceModel[],
  context: MarketplaceModel[],
  valueOf: (m: MarketplaceModel) => T | null,
  labels: Partial<Record<T, string>>,
  order?: T[],
): FacetOption[] {
  const totals = new Map<T, number>();
  for (const m of all) {
    const v = valueOf(m);
    if (v !== null) totals.set(v, (totals.get(v) ?? 0) + 1);
  }
  const counts = new Map<T, number>();
  for (const m of context) {
    const v = valueOf(m);
    if (v !== null) counts.set(v, (counts.get(v) ?? 0) + 1);
  }
  const values = order
    ? order.filter((v) => totals.has(v))
    : [...totals.keys()].sort((a, b) => (labels[a] ?? a).localeCompare(labels[b] ?? b));
  return values.map((v) => ({ value: v, label: labels[v] ?? v, count: counts.get(v) ?? 0 }));
}

export function FilterSidebar({
  models,
  filters,
  contextFor,
  onChange,
}: {
  models: MarketplaceModel[];
  filters: FilterState;
  contextFor: FacetContext;
  onChange: (next: FilterState) => void;
}) {
  const set = <K extends keyof FilterState>(key: K, value: FilterState[K]) =>
    onChange({ ...filters, [key]: value });

  const toggleIn = (key: 'categories' | 'brands' | 'propulsion' | 'equipment' | 'keel', value: string) => {
    const list = filters[key] as string[];
    set(
      key,
      (list.includes(value) ? list.filter((v) => v !== value) : [...list, value]) as FilterState[typeof key],
    );
  };

  const categoryOptions = buildOptions<BoatCategory>(
    models,
    contextFor('categories'),
    (m) => m.category,
    CATEGORY_LABELS,
  );

  const brandLabels: Record<string, string> = {};
  for (const m of models) {
    if (m.manufacturers?.slug) brandLabels[m.manufacturers.slug] = m.manufacturers.name;
  }
  const brandOptions = buildOptions<string>(
    models,
    contextFor('brands'),
    (m) => m.manufacturers?.slug ?? null,
    brandLabels,
  );

  const propulsionOptions = buildOptions<PropulsionType>(
    models,
    contextFor('propulsion'),
    (m) => m.propulsion_type,
    PROPULSION_LABELS,
    ['electric', 'hybrid_electric', 'conventional'],
  );

  const engineContext = contextFor('engines');
  const engineTotals = new Set(models.map((m) => m.engine_count).filter((n): n is number => n !== null));
  const engineOptions: FacetOption[] = [...engineTotals]
    .sort((a, b) => a - b)
    .map((n) => ({
      value: String(n),
      label: n === 1 ? '1 motor' : `${n} motors`,
      count: engineContext.filter((m) => m.engine_count === n).length,
    }));

  const keelOptions = buildOptions<string>(models, contextFor('keel'), (m) => m.keel_type, KEEL_LABELS);

  const equipmentContext = contextFor('equipment');
  const equipmentGroups = EQUIPMENT_GROUPS.map((group) => ({
    group: group.group,
    options: group.items
      .filter((item) => models.some((m) => m.equipment?.includes(item.slug)))
      .map((item) => ({
        value: item.slug,
        label: item.label,
        count: equipmentContext.filter((m) => m.equipment?.includes(item.slug)).length,
      })),
  })).filter((g) => g.options.length > 0);

  const rangeSection = (
    title: string,
    key: 'price' | 'length' | 'beam' | 'draft' | 'airDraft' | 'range' | 'power' | 'cabins' | 'berths',
    unit: string | undefined,
    valueOf: (m: MarketplaceModel) => number | null,
    step?: number,
  ) => {
    const values = models.map(valueOf).filter((v): v is number => v !== null);
    if (values.length === 0) return null; // >=1-record rule for numeric groups too
    const min = Math.min(...values);
    const max = Math.max(...values);
    return (
      <FilterSection title={title} defaultOpen={filters[key].min !== null || filters[key].max !== null}>
        <RangeField
          value={filters[key]}
          onChange={(r: NumRange) => set(key, r)}
          minPlaceholder={String(min)}
          maxPlaceholder={String(max)}
          unit={unit}
          step={step}
        />
      </FilterSection>
    );
  };

  return (
    <div>
      <FilterSection title="Model">
        <SearchField value={filters.q} onChange={(q) => set('q', q)} placeholder="Search model or brand…" />
      </FilterSection>

      {rangeSection('Price', 'price', '€', (m) => m.price_from_eur)}

      <FilterSection title="Boat type">
        <CheckboxFacet options={categoryOptions} selected={filters.categories} onToggle={(v) => toggleIn('categories', v)} />
      </FilterSection>

      <FilterSection title="Brand" defaultOpen={filters.brands.length > 0}>
        <CheckboxFacet options={brandOptions} selected={filters.brands} onToggle={(v) => toggleIn('brands', v)} />
      </FilterSection>

      {propulsionOptions.length > 1 && (
        <FilterSection title="Propulsion">
          <CheckboxFacet options={propulsionOptions} selected={filters.propulsion} onToggle={(v) => toggleIn('propulsion', v)} />
        </FilterSection>
      )}

      {rangeSection('Range', 'range', 'nm', (m) => m.range_nm)}
      {rangeSection('Length', 'length', 'm', (m) => m.length_m, 0.1)}
      {rangeSection('Width (beam)', 'beam', 'm', (m) => m.beam_m, 0.1)}
      {rangeSection('Draught', 'draft', 'm', (m) => m.draft_m, 0.1)}
      {rangeSection('Air draught', 'airDraft', 'm', (m) => m.air_draught_m, 0.1)}
      {rangeSection('Cabins', 'cabins', undefined, (m) => m.cabins)}
      {rangeSection('Berths', 'berths', undefined, (m) => m.berths)}

      {keelOptions.length > 0 && (
        <FilterSection title="Keel" defaultOpen={filters.keel.length > 0}>
          <CheckboxFacet options={keelOptions} selected={filters.keel} onToggle={(v) => toggleIn('keel', v)} />
        </FilterSection>
      )}

      {rangeSection('Motor power', 'power', 'kW', (m) => m.motor_power_kw)}

      {engineOptions.length > 1 && (
        <FilterSection title="Number of motors">
          <CheckboxFacet
            options={engineOptions}
            selected={filters.engines.map(String)}
            onToggle={(v) =>
              set(
                'engines',
                filters.engines.includes(Number(v))
                  ? filters.engines.filter((n) => n !== Number(v))
                  : [...filters.engines, Number(v)],
              )
            }
          />
        </FilterSection>
      )}

      {equipmentGroups.length > 0 && (
        <FilterSection title="Equipment" defaultOpen={filters.equipment.length > 0}>
          <div className="space-y-4">
            {equipmentGroups.map((g) => (
              <div key={g.group}>
                <p className="mb-1.5 text-[11px] font-semibold uppercase tracking-[0.14em] text-copper-soft">
                  {g.group}
                </p>
                <CheckboxFacet options={g.options} selected={filters.equipment} onToggle={(v) => toggleIn('equipment', v)} />
              </div>
            ))}
          </div>
        </FilterSection>
      )}
    </div>
  );
}
