// Pure filter-state helpers for the /models marketplace.
// Shared by the server page (parse searchParams -> initial state) and the
// client island (state -> URL via history.replaceState, in-memory filtering).

import type { BoatCategory, PropulsionType, ModelWithManufacturer } from '@/lib/supabase/types';

/** Listing row: model + manufacturer + engine count from the primary powertrain. */
export type MarketplaceModel = ModelWithManufacturer & { engine_count: number | null };

export type NumRange = { min: number | null; max: number | null };

export type FilterState = {
  q: string;
  categories: BoatCategory[];
  brands: string[]; // manufacturer slugs
  propulsion: PropulsionType[];
  engines: number[]; // motor_count values
  equipment: string[]; // canonical slugs, AND semantics
  keel: string[];
  price: NumRange; // price_from_eur
  length: NumRange; // length_m
  beam: NumRange; // beam_m
  draft: NumRange; // draft_m
  airDraft: NumRange; // air_draught_m
  range: NumRange; // range_nm
  power: NumRange; // motor_power_kw
  cabins: NumRange;
  berths: NumRange;
};

const EMPTY_RANGE: NumRange = { min: null, max: null };

export const EMPTY_FILTERS: FilterState = {
  q: '',
  categories: [],
  brands: [],
  propulsion: [],
  engines: [],
  equipment: [],
  keel: [],
  price: EMPTY_RANGE,
  length: EMPTY_RANGE,
  beam: EMPTY_RANGE,
  draft: EMPTY_RANGE,
  airDraft: EMPTY_RANGE,
  range: EMPTY_RANGE,
  power: EMPTY_RANGE,
  cabins: EMPTY_RANGE,
  berths: EMPTY_RANGE,
};

// URL param key per range field, kept short for readable URLs.
const RANGE_PARAMS: [keyof FilterState & string, string][] = [
  ['price', 'price'],
  ['length', 'len'],
  ['beam', 'beam'],
  ['draft', 'draft'],
  ['airDraft', 'air'],
  ['range', 'range'],
  ['power', 'power'],
  ['cabins', 'cabins'],
  ['berths', 'berths'],
];

function parseNum(s: string): number | null {
  const n = Number(s);
  return Number.isFinite(n) ? n : null;
}

/** "100-500" | "100-" | "-500" -> NumRange */
function parseRange(raw: string | undefined): NumRange {
  if (!raw) return EMPTY_RANGE;
  const idx = raw.indexOf('-');
  if (idx === -1) {
    const n = parseNum(raw);
    return n === null ? EMPTY_RANGE : { min: n, max: n };
  }
  const min = idx > 0 ? parseNum(raw.slice(0, idx)) : null;
  const max = idx < raw.length - 1 ? parseNum(raw.slice(idx + 1)) : null;
  return { min, max };
}

function serializeRange(r: NumRange): string | null {
  if (r.min === null && r.max === null) return null;
  return `${r.min ?? ''}-${r.max ?? ''}`;
}

function parseList(raw: string | undefined): string[] {
  if (!raw) return [];
  return raw.split(',').map((s) => s.trim()).filter(Boolean);
}

export function parseFilters(sp: Record<string, string | string[] | undefined>): FilterState {
  const get = (k: string): string | undefined => {
    const v = sp[k];
    return Array.isArray(v) ? v[0] : v;
  };

  // Legacy ?category= (homepage links) is an alias for cat=
  const cats = [...parseList(get('cat')), ...parseList(get('category'))];

  const state: FilterState = {
    ...EMPTY_FILTERS,
    q: get('q') ?? '',
    categories: [...new Set(cats)] as BoatCategory[],
    brands: parseList(get('brand')),
    propulsion: parseList(get('fuel')) as PropulsionType[],
    engines: parseList(get('eng'))
      .map((s) => Number(s))
      .filter((n) => Number.isInteger(n) && n > 0),
    equipment: parseList(get('eq')),
    keel: parseList(get('keel')),
  };
  for (const [field, param] of RANGE_PARAMS) {
    (state[field] as NumRange) = parseRange(get(param));
  }
  return state;
}

/** Returns '' for the empty state, otherwise '?a=b&c=d'. */
export function serializeFilters(f: FilterState): string {
  const params = new URLSearchParams();
  if (f.q.trim()) params.set('q', f.q.trim());
  if (f.categories.length) params.set('cat', f.categories.join(','));
  if (f.brands.length) params.set('brand', f.brands.join(','));
  if (f.propulsion.length) params.set('fuel', f.propulsion.join(','));
  if (f.engines.length) params.set('eng', f.engines.join(','));
  if (f.equipment.length) params.set('eq', f.equipment.join(','));
  if (f.keel.length) params.set('keel', f.keel.join(','));
  for (const [field, param] of RANGE_PARAMS) {
    const s = serializeRange(f[field] as NumRange);
    if (s !== null) params.set(param, s);
  }
  const qs = params.toString();
  return qs ? `?${qs}` : '';
}

/** Number of active filter groups (for the mobile "Filters (n)" button and chips). */
export function countActiveFilters(f: FilterState): number {
  let n = 0;
  if (f.q.trim()) n++;
  if (f.categories.length) n++;
  if (f.brands.length) n++;
  if (f.propulsion.length) n++;
  if (f.engines.length) n++;
  if (f.equipment.length) n++;
  if (f.keel.length) n++;
  for (const [field] of RANGE_PARAMS) {
    const r = f[field] as NumRange;
    if (r.min !== null || r.max !== null) n++;
  }
  return n;
}

/** NULL field + active range filter on it -> model excluded (marketplace convention). */
function inRange(value: number | null, r: NumRange): boolean {
  if (r.min === null && r.max === null) return true;
  if (value === null) return false;
  if (r.min !== null && value < r.min) return false;
  if (r.max !== null && value > r.max) return false;
  return true;
}

export function applyFilters(models: MarketplaceModel[], f: FilterState): MarketplaceModel[] {
  const q = f.q.trim().toLowerCase();
  return models.filter((m) => {
    if (q && !`${m.name} ${m.manufacturers?.name ?? ''}`.toLowerCase().includes(q)) return false;
    if (f.categories.length && !f.categories.includes(m.category)) return false;
    if (f.brands.length && !f.brands.includes(m.manufacturers?.slug ?? '')) return false;
    if (f.propulsion.length && !f.propulsion.includes(m.propulsion_type)) return false;
    if (f.engines.length && (m.engine_count === null || !f.engines.includes(m.engine_count))) return false;
    if (f.equipment.length && !f.equipment.every((slug) => m.equipment?.includes(slug))) return false;
    if (f.keel.length && (m.keel_type === null || !f.keel.includes(m.keel_type))) return false;
    if (!inRange(m.price_from_eur, f.price)) return false;
    if (!inRange(m.length_m, f.length)) return false;
    if (!inRange(m.beam_m, f.beam)) return false;
    if (!inRange(m.draft_m, f.draft)) return false;
    if (!inRange(m.air_draught_m, f.airDraft)) return false;
    if (!inRange(m.range_nm, f.range)) return false;
    if (!inRange(m.motor_power_kw, f.power)) return false;
    if (!inRange(m.cabins, f.cabins)) return false;
    if (!inRange(m.berths, f.berths)) return false;
    return true;
  });
}

export const KEEL_LABELS: Record<string, string> = {
  fin: 'Fin keel',
  full: 'Full keel',
  bulb: 'Bulb keel',
  wing: 'Wing keel',
  swing: 'Swing keel',
  lifting: 'Lifting keel',
  centreboard: 'Centreboard',
  daggerboard: 'Daggerboard',
  twin: 'Twin keel',
  none: 'No keel (planing hull)',
};

export const PROPULSION_LABELS: Record<PropulsionType, string> = {
  electric: 'Electric',
  hybrid_electric: 'Hybrid electric',
  conventional: 'Conventional',
};
