-- Marketplace filter columns: cabins, berths, air draught, keel, equipment
-- Applied 2026-07-21 via: npx supabase db query --linked -f supabase/queries/2026-07-21_marketplace_filter_columns.sql
-- Mirrored into electroyachts_schema.sql (source of truth) in the same commit.

alter table models
  add column if not exists cabins        smallint,
  add column if not exists berths        smallint,
  add column if not exists air_draught_m numeric(5,2),
  add column if not exists keel_type     text,
  add column if not exists equipment     text[] not null default '{}';

-- keel_type: text + CHECK, not enum — mostly-null column (motorboats).
-- 'none' = explicitly keel-less; NULL = unknown/not applicable.
alter table models
  add constraint chk_models_keel_type check (
    keel_type is null or keel_type in
    ('fin','full','bulb','wing','swing','lifting','centreboard','daggerboard','twin','none')
  );

-- equipment holds canonical kebab-case slugs from src/lib/marketplace/equipment.ts
create index if not exists idx_models_equipment on models using gin (equipment);
