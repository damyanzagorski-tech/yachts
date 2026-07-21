-- =====================================================================
-- electroyachts.com — Core Database Schema (v1)
-- Target: PostgreSQL 15+ (Supabase / Neon compatible)
-- Scope: 5 core tables — Manufacturers, Models, Leads, Deals, Content/SEO
-- =====================================================================

-- ---------------------------------------------------------------------
-- Extensions
-- ---------------------------------------------------------------------
create extension if not exists "pgcrypto";      -- gen_random_uuid()
create extension if not exists "citext";         -- case-insensitive text (emails, slugs)

-- ---------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------
create type manufacturer_status as enum ('prospect', 'contacted', 'partner', 'active', 'inactive');
create type manufacturer_product_line as enum ('electric_only', 'mixed_electric_conventional');
create type boat_category      as enum ('day_boat', 'cruiser', 'catamaran', 'tender', 'sport', 'limousine', 'other');
create type propulsion_type    as enum ('electric', 'hybrid_electric', 'conventional');
create type market_tier        as enum ('entry', 'premium', 'luxury', 'ultra_luxury');
create type lead_status        as enum ('new', 'qualified', 'call_booked', 'offer_sent', 'won', 'lost');
create type lead_source        as enum ('organic_seo', 'paid_ads', 'referral', 'direct', 'newsletter', 'partner', 'other');
create type deal_status        as enum ('open', 'negotiation', 'contract_sent', 'deposit_paid', 'won', 'lost', 'cancelled');
create type content_status     as enum ('draft', 'in_review', 'published', 'needs_update', 'archived');
create type content_type       as enum ('review', 'news', 'buyer_guide', 'comparison', 'landing_page', 'manufacturer_page', 'model_page');

-- ---------------------------------------------------------------------
-- Utility: auto-update updated_at
-- ---------------------------------------------------------------------
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- =====================================================================
-- 1. MANUFACTURERS
-- =====================================================================
create table manufacturers (
    id                  uuid primary key default gen_random_uuid(),
    name                text not null,
    slug                citext unique not null,
    country             text,                          -- HQ country
    website             text,
    logo_url            text,
    description         text,
    founded_year         smallint,

    -- contact / partnership
    contact_name        text,
    contact_email       citext,
    contact_phone       text,
    linkedin_url        text,

    -- business terms
    status              manufacturer_status not null default 'prospect',
    product_line        manufacturer_product_line not null default 'electric_only',
    has_affiliate_program boolean not null default false,
    commission_rate_pct numeric(5,2),                   -- e.g. 3.00 = 3%
    partnership_notes   text,

    -- marketing tier (from monetization model)
    listing_tier        text default 'basic',           -- basic / premium / platinum
    tier_expires_at      date,

    -- verification
    is_verified         boolean not null default false,
    verified_at          timestamptz,

    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now()
);

create trigger trg_manufacturers_updated_at
before update on manufacturers
for each row execute function set_updated_at();

create index idx_manufacturers_status on manufacturers(status);
create index idx_manufacturers_country on manufacturers(country);

-- =====================================================================
-- 2. MODELS
-- =====================================================================
create table models (
    id                  uuid primary key default gen_random_uuid(),
    manufacturer_id     uuid not null references manufacturers(id) on delete cascade,

    name                text not null,
    slug                citext unique not null,
    category            boat_category not null default 'other',
    propulsion_type     propulsion_type not null default 'electric',
    market_tier         market_tier,             -- entry / premium / luxury / ultra_luxury; nullable until classified

    -- dimensions
    length_m            numeric(5,2),
    beam_m              numeric(5,2),
    draft_m             numeric(5,2),
    weight_kg           integer,

    -- capacity & performance
    passenger_capacity  smallint,
    battery_kwh         numeric(6,2),
    motor_power_kw      numeric(6,2),
    top_speed_knots     numeric(5,2),
    range_nm            numeric(6,2),                   -- nautical miles at cruise speed
    charging_time_hours numeric(5,2),

    -- accommodation & hull (marketplace filters)
    cabins              smallint,
    berths              smallint,
    air_draught_m       numeric(5,2),
    keel_type           text,             -- see CHECK below; 'none' = keel-less planing hull, NULL = unknown/N-A
    equipment           text[] not null default '{}',   -- canonical kebab-case slugs from src/lib/marketplace/equipment.ts

    -- commercial
    price_from_eur      numeric(12,2),
    price_to_eur        numeric(12,2),
    ce_category         text,                            -- e.g. "CE Category B"

    -- content
    description         text,
    hero_image_url      text,
    gallery_urls        text[],           -- general lifestyle/detail photos
    color_variant_urls  text[],           -- hull colour configurator renders, one per colour option
    video_url           text,
    brochure_url         text,

    is_featured         boolean not null default false,
    is_sponsored        boolean not null default false,
    sponsored_until      date,

    status              text not null default 'active',  -- active / discontinued / upcoming

    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now(),

    constraint chk_models_keel_type check (
        keel_type is null or keel_type in
        ('fin','full','bulb','wing','swing','lifting','centreboard','daggerboard','twin','none')
    )
);

create trigger trg_models_updated_at
before update on models
for each row execute function set_updated_at();

create index idx_models_manufacturer on models(manufacturer_id);
create index idx_models_category on models(category);
create index idx_models_propulsion on models(propulsion_type);
create index idx_models_market_tier on models(market_tier);
create index idx_models_price on models(price_from_eur);
create index idx_models_equipment on models using gin (equipment);

-- =====================================================================
-- 2b. MODEL POWERTRAINS (detailed, queryable engine/motor data)
-- =====================================================================
-- Why a separate table: many boat models (Delphia 10, Rand Source 22,
-- Alfastreet's whole range, Greenline's whole range) are sold with a
-- CHOICE of drivetrain — e.g. diesel OR electric OR hybrid on the same
-- hull. Bolting motor_brand/battery columns onto `models` would force
-- one row per drivetrain variant and make "which motor brand powers
-- this boat" an unreliable, string-parsing query. Instead each engine
-- configuration is its own row here, so you can query things like:
--   "all boats using a Torqeedo Deep Blue motor"
--   "all boats with >100kWh battery and electric propulsion"
--   "every drivetrain option available for model X"
-- The summary columns still kept on `models` (battery_kwh,
-- motor_power_kw, top_speed_knots, range_nm, price_from_eur) represent
-- the PRIMARY/default configuration for quick listing pages; this table
-- is the authoritative, fully queryable source for engine-level detail.

create table model_powertrains (
    id                  uuid primary key default gen_random_uuid(),
    model_id            uuid not null references models(id) on delete cascade,

    propulsion_type     propulsion_type not null default 'electric',
    is_primary          boolean not null default true,  -- the configuration shown on models.* summary columns

    -- motor
    motor_brand         text,          -- e.g. 'Torqeedo', 'Evoy', 'Kreisel', 'Candela C-Pod', 'Volvo Penta'
    motor_model         text,          -- e.g. 'Deep Blue 50i', 'Storm', 'D3'
    motor_count         smallint not null default 1,
    motor_power_kw      numeric(7,2),  -- total combined power across all motors

    -- battery (electric / hybrid_electric only)
    battery_brand        text,          -- e.g. 'Polestar', 'Kreisel', 'BMW i3-derived'
    battery_kwh           numeric(7,2),
    charging_time_hours    numeric(5,2),
    fast_charge_minutes     integer,       -- time for 10-80% or similar, if known

    -- performance for THIS configuration specifically
    top_speed_knots          numeric(5,2),
    cruise_speed_knots        numeric(5,2),
    range_nm                    numeric(6,2),
    range_at_knots                numeric(5,2),  -- speed at which the range figure applies

    price_from_eur                 numeric(12,2),  -- price for this specific configuration, if it differs from base
    notes                            text,

    created_at                        timestamptz not null default now(),
    updated_at                        timestamptz not null default now()
);

create trigger trg_model_powertrains_updated_at
before update on model_powertrains
for each row execute function set_updated_at();

create index idx_powertrains_model on model_powertrains(model_id);
create index idx_powertrains_type on model_powertrains(propulsion_type);
create index idx_powertrains_motor_brand on model_powertrains(motor_brand);

-- =====================================================================
-- 3. LEADS / BUYERS
-- =====================================================================
create table leads (
    id                  uuid primary key default gen_random_uuid(),

    full_name           text,
    email               citext,
    phone               text,
    country             text,
    preferred_language  text default 'en',

    -- interest
    interested_model_id uuid references models(id) on delete set null,
    interested_category boat_category,
    budget_min_eur       numeric(12,2),
    budget_max_eur       numeric(12,2),
    purchase_timeframe  text,                            -- e.g. "0-3 months", "6-12 months"

    -- tracking
    source               lead_source not null default 'other',
    source_domain        text,
    utm_campaign         text,

    -- scoring & pipeline
    lead_score           smallint default 0,             -- 0-100
    status                lead_status not null default 'new',
    notes                 text,

    -- GDPR: when the visitor ticked the required consent checkbox on the
    -- public enquiry form (EU audience)
    gdpr_consent_at       timestamptz,

    created_at            timestamptz not null default now(),
    updated_at            timestamptz not null default now()
);

create trigger trg_leads_updated_at
before update on leads
for each row execute function set_updated_at();

create index idx_leads_status on leads(status);
create index idx_leads_country on leads(country);
create index idx_leads_model on leads(interested_model_id);

-- =====================================================================
-- 4. DEALS / SALES PIPELINE
-- =====================================================================
create table deals (
    id                  uuid primary key default gen_random_uuid(),

    lead_id             uuid not null references leads(id) on delete cascade,
    manufacturer_id     uuid not null references manufacturers(id) on delete restrict,
    model_id            uuid references models(id) on delete set null,

    sale_price_eur       numeric(12,2),
    commission_rate_pct  numeric(5,2),
    commission_amount_eur numeric(12,2) generated always as
        (coalesce(sale_price_eur,0) * coalesce(commission_rate_pct,0) / 100) stored,

    deposit_paid_eur      numeric(12,2),
    expected_close_date   date,
    actual_close_date     date,

    status                deal_status not null default 'open',
    notes                 text,

    created_at             timestamptz not null default now(),
    updated_at             timestamptz not null default now()
);

create trigger trg_deals_updated_at
before update on deals
for each row execute function set_updated_at();

create index idx_deals_status on deals(status);
create index idx_deals_manufacturer on deals(manufacturer_id);
create index idx_deals_lead on deals(lead_id);

-- =====================================================================
-- 5. CONTENT / SEO PAGES  (multilingual: group -> translations)
-- =====================================================================
-- A "page group" represents ONE conceptual page (e.g. "Electric yachts
-- Germany buyer guide"). Each language version is a row in content_pages
-- that points back to the same group, so shared metadata (content type,
-- related manufacturer/model, target country) lives once, while title,
-- slug, body, and SEO performance are tracked per language.

create table content_page_groups (
    id                       uuid primary key default gen_random_uuid(),
    group_key                citext unique not null,      -- e.g. 'electric-yachts-germany-guide'
    content_type             content_type not null default 'landing_page',
    country                  text,                          -- target country, if geo-specific

    related_manufacturer_id  uuid references manufacturers(id) on delete set null,
    related_model_id         uuid references models(id) on delete set null,

    created_at                timestamptz not null default now(),
    updated_at                timestamptz not null default now()
);

create trigger trg_content_page_groups_updated_at
before update on content_page_groups
for each row execute function set_updated_at();

create index idx_content_groups_type on content_page_groups(content_type);
create index idx_content_groups_country on content_page_groups(country);

create table content_pages (
    id                  uuid primary key default gen_random_uuid(),
    page_group_id       uuid not null references content_page_groups(id) on delete cascade,

    title                text not null,
    slug                 citext not null,
    url_path             text not null,                  -- e.g. /de/elektro-yachten-deutschland
    language             text not null default 'en',      -- ISO 639-1

    primary_keyword      text,
    meta_description      text,
    body_markdown         text,

    status                content_status not null default 'draft',
    published_at           timestamptz,

    -- performance tracking (updated periodically by analytics job)
    monthly_traffic         integer default 0,
    avg_search_position      numeric(5,2),
    conversions              integer default 0,

    created_at               timestamptz not null default now(),
    updated_at               timestamptz not null default now(),

    unique (page_group_id, language),   -- one translation per language per group
    unique (language, slug)              -- URL uniqueness within a language
);

create trigger trg_content_pages_updated_at
before update on content_pages
for each row execute function set_updated_at();

create index idx_content_status on content_pages(status);
create index idx_content_language on content_pages(language);
create index idx_content_page_group on content_pages(page_group_id);

-- =====================================================================
-- ROW LEVEL SECURITY (Supabase)
-- =====================================================================
-- Model:
--   - manufacturers, models, content_page_groups, content_pages
--       -> publicly readable (this is what the website renders),
--          writable only by staff.
--   - leads, deals
--       -> contain PII / commercial terms -> NOT publicly readable,
--          staff-only for both read and write.
--   - service_role (used by backend jobs / API routes) bypasses RLS
--     entirely by default in Supabase, so cron jobs, the SEO agent,
--     etc. keep working without needing a policy of their own.

-- Staff directory: maps a Supabase auth user to a role.
create table staff_users (
    user_id     uuid primary key references auth.users(id) on delete cascade,
    role        text not null default 'editor',   -- editor | admin
    created_at  timestamptz not null default now()
);

create or replace function is_staff()
returns boolean as $$
  select exists (
    select 1 from staff_users where user_id = auth.uid()
  );
$$ language sql security definer stable;

-- ---- manufacturers ----
alter table manufacturers enable row level security;

create policy "manufacturers_public_read"
on manufacturers for select
using (true);

create policy "manufacturers_staff_write"
on manufacturers for all
using (is_staff())
with check (is_staff());

-- ---- models ----
alter table models enable row level security;

create policy "models_public_read"
on models for select
using (true);

create policy "models_staff_write"
on models for all
using (is_staff())
with check (is_staff());

-- ---- model_powertrains ----
alter table model_powertrains enable row level security;

create policy "powertrains_public_read"
on model_powertrains for select
using (true);

create policy "powertrains_staff_write"
on model_powertrains for all
using (is_staff())
with check (is_staff());

-- ---- content_page_groups ----
alter table content_page_groups enable row level security;

create policy "content_groups_public_read"
on content_page_groups for select
using (true);

create policy "content_groups_staff_write"
on content_page_groups for all
using (is_staff())
with check (is_staff());

-- ---- content_pages ----
alter table content_pages enable row level security;

create policy "content_pages_public_read_published"
on content_pages for select
using (status = 'published' or is_staff());

create policy "content_pages_staff_write"
on content_pages for all
using (is_staff())
with check (is_staff());

-- ---- leads (PII — staff only, no public access) ----
alter table leads enable row level security;

create policy "leads_staff_only"
on leads for all
using (is_staff())
with check (is_staff());

-- ---- deals (commercial terms — staff only) ----
alter table deals enable row level security;

create policy "deals_staff_only"
on deals for all
using (is_staff())
with check (is_staff());

-- Public enquiry form (model pages) inserts with the anon key. INSERT
-- only — SELECT/UPDATE/DELETE stay staff-only via leads_staff_only.
-- with check constrains inserts to fresh, unscored rows so the anon role
-- can't inject pre-qualified/scored leads.
create policy "leads_public_insert"
on leads for insert
to anon
with check (status = 'new' and lead_score = 0);

-- =====================================================================
-- SEED DATA — Manufacturers
-- =====================================================================
insert into manufacturers (name, slug, country, website, status, product_line, has_affiliate_program, commission_rate_pct, is_verified, partnership_notes)
values
    ('Candela',        'candela',        'Sweden',  'https://candela.com',            'active',   'electric_only',              false, 3.00, true,  'Hydrofoiling electric day boats; no formal affiliate program found — direct outreach recommended.'),
    ('X Shore',        'x-shore',        'Sweden',  'https://xshore.com',             'active',   'electric_only',              false, 2.50, true,  'Planing-hull electric day cruisers; strong US + EU dealer network.'),
    ('Frauscher',      'frauscher',      'Austria', 'https://frauscherboats.com',      'active',   'mixed_electric_conventional', false, 2.00, true,  'Traditional Austrian shipyard with a full conventional range; electric line via Porsche collaboration (Fantom Air) is one model within a mostly combustion catalog.'),
    ('Silent Yachts',  'silent-yachts',  'Austria', 'https://silent-yachts.com',       'active',   'electric_only',              false, 2.00, true,  'Solar-electric catamarans, ocean-crossing capable; premium price point. Diesel gensets are range-extenders only, not a conventional propulsion line.'),
    ('Sunreef Yachts', 'sunreef-yachts', 'Poland',  'https://sunreef-yachts.com',      'active',   'mixed_electric_conventional', false, 1.50, true,  'Large luxury sailing/power catamaran builder; Eco/electric line is one segment within a much larger conventional (diesel/hybrid) range.'),
    ('ALVA Yachts',    'alva-yachts',    'Germany', 'https://www.alva-yachts.com',     'prospect', 'electric_only',              false, null, false, 'Solar-assisted electric catamarans and monohulls; targeted for direct manufacturer outreach per SEO Domains strategy.'),
    ('Greenline Yachts','greenline-yachts','Slovenia','https://greenlineyachts.com',   'prospect', 'mixed_electric_conventional', false, null, false, 'Diesel-electric hybrid range alongside conventional diesel models; relevant for hybrid/electric comparison content, not pure-electric.'),
    ('Crooze Yachts',   'crooze-yachts',   'Bulgaria','https://croozeyachts.com',      'prospect', 'electric_only',              false, null, false, 'Bulgarian all-electric day boat builder. EZ 28 was a 2025 Gussies Electric Boat Awards finalist (Concept/In Development, over 8m category). Local market — worth a direct outreach given SEO Domains'' Bulgaria base.'),
    ('Axopar',         'axopar',         'Finland', 'https://www.axopar.com',          'active',   'mixed_electric_conventional', false, null, true,  'Core Axopar range (6 models, 22-45ft) is gas/diesel; AX/E is a dedicated fully-electric sub-brand (AX/E 22, AX/E 25) launched 2024 with Evoy outboard motors. Over 6,000 boats sold historically across the conventional range.'),
    ('Marian Boats',    'marian-boats',   'Austria', 'https://marianboats.at',         'active',   'electric_only',              false, null, true,  'Austrian family business at Lake Wolfgang, Salzburg; entire catalog (M 800, Laguna 760, Capriole 700, etc.) is electric-only since founding in 2000/2001.'),
    ('ARC Boats',       'arc-boats',      'United States','https://arcboats.com',      'active',   'electric_only',              false, null, true,  'Los Angeles-based EV-adjacent startup (ex-SpaceX/Tesla engineers). Fully electric-only range: Arc One, Arc Sport, Arc Coast, plus electric/hybrid workboats. Not EU-based but relevant as a US benchmark competitor for content/comparisons.'),
    ('Strana Electric Boats', 'strana-electric-boats', 'Sweden', null, 'active', 'electric_only', false, null, true, 'Swedish recreational electric boat manufacturer positioning itself around a sustainable-lifestyle-at-sea brand identity, listed via the GoElectric dealer network.'),
    ('POL Lux',          'pol-lux',        'Sweden', null,             'active',   'electric_only',              false, null, true,  'Swedish-built solar-electric catamaran brand, designed from the ground up for electric propulsion. Reconfigurable open deck (sunbed / sleeping area / cargo space) with a roll-down canvas enclosure; roof-mounted solar panels charge the battery both underway and at dock.'),
    ('Alfastreet',      'alfastreet',     'Slovenia','https://www.alfastreet-marine.com','active', 'mixed_electric_conventional', false, null, true,  'Slovenian day-boat builder; nearly every model in the range is available as a factory-fit electric version alongside the standard petrol/sterndrive option — a strong "same hull, electric option" case study.'),
    ('Boesch',          'boesch-boats',   'Switzerland','https://www.boesch-boote.ch',  'active',   'mixed_electric_conventional', false, null, true,  'Swiss wooden-hull sportsboat yard since 1910; conventional mid-engine range from 20-32ft, with electric powertrains offered on models up to 25ft.'),
    ('Delphia',         'delphia-yachts', 'Poland','https://www.delphiayachts.com',     'active',   'mixed_electric_conventional', false, null, true,  'Polish yard, part of Groupe Beneteau since 2021. Delphia 10 (Vripack design) offers a straight choice of diesel engine or electric shaft drive on the same hull.'),
    ('Four Winns',      'four-winns',     'United States','https://www.fourwinns.com',  'active',   'mixed_electric_conventional', false, null, true,  'Groupe Beneteau-owned US bowrider brand; primarily petrol-powered, with the H2e positioned as the first all-electric series-production bowrider.'),
    ('Hinckley',        'hinckley-yachts','United States','https://www.hinckleyyachts.com','active','mixed_electric_conventional', false, null, true,  'Legendary New England picnic-boat builder, historically combustion-only; the Dasher is its first all-electric model, hand-built alongside its conventional range.'),
    ('Nimbus',          'nimbus-boats',   'Sweden','https://www.nimbus.se',             'active',   'mixed_electric_conventional', false, null, true,  'Established Swedish yard; the 305 Coupe was originally a combustion design later adapted to electric propulsion (E-Power) as an option, not a ground-up electric model.'),
    ('Rand Boats',      'rand-boats',     'Denmark','https://www.randboats.com',        'active',   'mixed_electric_conventional', false, null, true,  'Danish sportsboat builder, HQ Copenhagen. Current full lineup (per randboats.com, checked mid-2026) spans 13 models in three lines: Social (Breeze 20, Mana 24, Solara 33), Sports (Source 23, Play 24, Spirit 25, Supreme 27, Leisure 28, Roamer 29), and Yacht (Escape 32, Archipelago 32, Lagune 44, Realm 45). NOTE: this dataset''s existing "Source 22" and "Mana 23" entries were sourced from older (2023) articles — the current model names are Source 23 and Mana 24, suggesting a generation update. Treat the older entries as potentially superseded until each is re-verified individually; specs for the current-generation models were not available on the manufacturer''s boat-listing page (marketing copy only, no numbers) and would need per-model page visits to confirm.'),
    ('Riva',            'riva-yacht',     'Italy','https://www.riva-yacht.com',          'active',   'mixed_electric_conventional', false, null, true,  'Iconic Italian yard (Ferretti Group); El-Iseo is an all-electric prototype version of the combustion-powered Riva Iseo, not yet released for sale.'),
    ('Nautique',        'nautique',       'United States','https://www.nautique.com',   'active',   'mixed_electric_conventional', false, null, true,  'US wake-sports specialist; the GS22E is an electric version of the petrol-powered Super Air Nautique GS22, sold at a significant premium over the combustion model.'),
    ('Zodiac Nautic',   'zodiac-nautic',  'France','https://www.zodiac-nautic.com',      'active',   'mixed_electric_conventional', false, null, true,  'Long-established French RIB manufacturer (est. 1896); building a dedicated electric jet-RIB line (e-jet, eOpen) alongside its conventional inflatable/RIB range, largely for superyacht tender use.'),
    ('Sialia Yachts',   'sialia-yachts',  'Cyprus','https://www.sialia-yachts.com',       'active',   'electric_only',              false, null, true,  'Founded 2017 (Silent Straits Ltd, Limassol); design/engineering team spread across Poland, France, Netherlands, Spain and Switzerland. Proprietary AMPROS electric propulsion system. 7 models currently in production (13.7m-26.6m range), entirely electric, no combustion lineup. Strong fit for premium manufacturer outreach given the site''s European focus.'),
    ('Vita Power',      'vita-power',     'United Kingdom','https://vita-power.com',      'active',   'electric_only',              false, null, true,  'UK-based (also offices in Monaco, Italy, US) electric propulsion and boat systems company, founded 2017. Positions itself as a "propulsion and energy systems enabler" rather than a traditional shipyard — builds its own Seal/SeaDog RIBs and Lion day boat, and partners with other builders (Hodgdon Yachts for hull construction, Maserati for the Tridente collaboration, SAFE Boats International for patrol boats). Sister company Aqua superPower runs marine DC fast-charging infrastructure.'),
    ('TYDE',            'tyde',           'Germany','https://www.tyde.tech',              'active',   'electric_only',              false, null, true,  'German electric-foiling startup, still in early-stage development as of this data. Known for THE ICON, a collaboration with BMW — a foiling passenger vessel rather than a conventional recreational boat, aimed at B2B luxury ferry/transfer use (resort-to-mainland, airport-to-harbour) rather than direct retail sale.'),
    ('Enata Marine',    'enata-marine',   'United Arab Emirates','https://foiler.com',      'active',   'mixed_electric_conventional', false, null, true,  'UAE-based watertoy and boat specialist; the Foiler is a diesel-electric HYBRID, not a pure-electric product — flagged distinctly since it could otherwise be mistaken for all-electric given its "silent running" foiling mode.'),
    ('Flux Marine',     'flux-marine',    'United States','https://www.fluxmarine.com',   'active',   'electric_only',              false, null, true,  'Rhode Island-based electric outboard motor maker that also sells complete "boat packages" by pairing its propulsion with hulls from conventional builders (Scout Boats, Highfield, others). Listed here as the seller-of-record for its packages; the underlying hull manufacturers (Scout Boats, Highfield) are themselves conventional/mixed builders.'),
    ('Magonis',         'magonis',        'Spain','https://magonisboats.com',              'active',   'electric_only',              false, null, true,  'Trans-Mediterranean electric boat brand, founded 2017, based in Barcelona with production in Sabaudia, Italy. All-electric day boats built with lightweight vacuum-infusion composite construction. Strong fit for direct European outreach given HQ location.'),
    ('Chris-Craft',     'chris-craft',    'United States','https://www.chriscraft.com',    'active',   'mixed_electric_conventional', false, null, true,  'America''s boatbuilder since 1874 (subsidiary of Winnebago Industries); overwhelmingly a combustion/sterndrive builder. Its Launch 25 GTe is a CONCEPT, not yet in commercial production — flag this distinction when displaying on the site.'),
    ('Elvene',          'elvene',         'Finland','https://elveneboats.com',              'active',   'electric_only',              false, null, true,  'Finnish solar-electric boat builder based in Jakobstad, a historic Finnish boatbuilding town. All-electric range with solar-assist for extended range.'),
    ('Princecraft',     'princecraft',    'Canada','https://www.princecraft.com',           'active',   'mixed_electric_conventional', false, null, true,  'Established Canadian pontoon-boat manufacturer; the "Brio e" series is a dedicated all-electric line within an otherwise conventional (gas outboard) pontoon range.'),
    ('Volare Boats',    'volare-boats',   'United States','https://www.volareboats.com',    'active',   'electric_only',              false, null, true,  'North Carolina-based electric boat startup founded by former Scout Boats engineers/executives. Electric-only, semi-foiling catamaran hulls purpose-built for electric propulsion (not a converted combustion hull).'),
    ('NovaLuxe',        'novaluxe',       'United States','https://novaluxeyachts.com',      'active',   'mixed_electric_conventional', false, null, true,  'US builder of solar/electric multihulls; the Orphie 39 is described as its "only electric trimaran," implying other NovaLuxe models (larger liveaboard multihulls) may not be pure-electric — treated as mixed pending further confirmation.'),
    ('Vision Marine Technologies', 'vision-marine', 'Canada','https://visionmarinetechnologies.com', 'active', 'electric_only', false, null, true, 'Canadian electric propulsion specialist (25+ years in the marine industry) that has expanded from outboard motors (E-Motion powertrain) into complete electric boats: pontoons (V24, V30), rotomolded day boats (Phantom, Fantail 217, Volt 180), and performance models (SPECTR, Sterk31e). E-Motion tech set a boat speed record of 109 mph in 2022.'),
    ('Cosmopolitan Yachts', 'cosmopolitan-yachts', 'Spain','https://cosmopolitanyachts.com', 'active', 'electric_only', false, null, true, 'Spanish yard building large solar/electric catamarans; per MBY (2023), uses batteries, solar panels, and ICE generators together — the generators appear to function as range-extenders for an electric drivetrain (similar pattern to Silent Yachts), not as a separate conventional propulsion line.'),
    ('Duffy',            'duffy',          'United States','https://duffyboats.com',       'active',   'electric_only',              false, null, true,  'The best-selling electric boat brand in the world — over 14,000 sold since 1970, ~3,500 in home port Newport Beach, California alone. Slow-speed (5.5kn) bay/lake cruisers, not a performance product, but a long-standing proof that electric boating can be mainstream.'),
    ('Hermes (Seven Seas Yachts)', 'hermes-seven-seas', 'United Kingdom','https://sevenseasyachts.co.uk', 'active', 'mixed_electric_conventional', false, null, true, 'UK-based reseller/brand for the Greek-built Hermes Speedster, styled after Porsche''s classic 356 Speedster. Typically sold with a 115hp Rotax petrol engine; the Speedster E is an eco-friendly electric option added since ~2020.'),
    ('Mantaray',         'mantaray',       null,             null,                          'active',   'mixed_electric_conventional', false, null, false, 'Builder of the Mannerfelt-designed Mantaray M24 foiling runabout, using a patented mechanical hydrofoil system (Dynamic Wing Technology) as an alternative to Candela-style electronic foil control. Country/full manufacturer details not confirmed in this research pass — flagged for follow-up before publishing.'),
    ('Mayla Yachts',     'mayla-yachts',   'Germany','https://maylayachts.com',             'active',   'electric_only',              false, null, true,  'German start-up building the Mayla FortyFour, an ultralight carbon-fibre performance boat on a Petestep hull, targeting 70+ knot top speeds. Offered in both all-electric and hybrid (smaller battery + diesel generator) configurations.'),
    ('Navier',           'navier',         'United States','https://navier.tech',           'active',   'electric_only',              false, null, true,  'Silicon Valley foiling-boat start-up (Sergey Brin-backed), building the carbon-hulled Navier N30 with retractable hydrofoils. Built at Lyman-Morse shipyard in Maine. 2023 production run reportedly sold out.'),
    ('Nero',             'nero-boats',     'Germany','https://nero-boats.com',              'active',   'electric_only',              false, null, true,  'Designed in Italy, built in Germany. Nero 777 Evolution uses a Petestep hull with a choice of five Evoy propulsion systems (60-300kW), targeting fold-down beach-club styling in a compact footprint.'),
    ('Optima',           'optima-yachts',  null,             null,                          'active',   'electric_only',              false, null, false, 'Builder of the Optima E10, a stabilised monohull with slender outrigger-style side hulls for efficient displacement-speed cruising. Country/manufacturer details not confirmed in this research pass.'),
    ('Pixii',            'pixii',          'United Kingdom','https://pixiiboats.com',        'active',   'electric_only',              false, null, true,  'British start-up (Isle of Wight) building the aluminium-hulled Pixii SP800 jet-drive electric sportsboat, aiming for a class-leading 150kWh battery pack.'),
    ('Persico Zagato',   'persico-zagato', 'Italy','https://persico.com',                   'active',   'electric_only',              false, null, true,  'Collaboration between Italian performance-boat specialist Persico and automotive design house Zagato, built around a steerable electric waterjet pod from Sealence (DeepSpeed 420). This entry covers only the Zagato-collaboration electric line, not Persico''s wider composite racing-boat business.'),
    ('Q-Yachts',         'q-yachts',       'Finland','https://q-yachts.com',                'active',   'electric_only',              false, null, true,  'Finnish yard established 2016, aiming to bring sailing-boat-like silent cruising to a motorboat without sails or crew. All models are electric.'),
    ('Ripple Boats',     'ripple-boats',   'Norway','https://rippleboats.com',               'active',   'electric_only',              false, null, true,  'Norwegian start-up founded by Frydenbø Marine and Pascal Technologies, raised over €4m in funding. Debut model designed by Thorup Design; plans for a wider 6-11m electric range if successful.'),
    ('RS Sailing',       'rs-sailing',     'United Kingdom','https://rspulse.com',           'active',   'mixed_electric_conventional', false, null, true,  'British dinghy-sailing specialist (RS range) that branched into the first British production-ready electric planing RIB, the RS Pulse 63, using a RAD Propulsion motor system. Core business remains sailing dinghies, not electric boats — hence mixed classification.'),
    ('SAY Carbon Yachts','say-carbon-yachts','Germany','https://saycarbon.com',              'active',   'mixed_electric_conventional', false, null, true,  'German ultralight carbon-fibre performance-boat specialist; the 29 E is an electric version of its combustion-powered 29 model. Holds the record (as of 2018) for fastest production electric boat under 9m.'),
    ('Spirit Yachts',    'spirit-yachts',  'United Kingdom','https://spirityachts.com',       'active',   'mixed_electric_conventional', false, null, true,  'UK builder primarily known for large wooden sailing superyachts (e.g. the 111ft Geist); the SpiritBARTech 35EF electric foiler was a one-off chase-boat commission for an existing sailing-yacht client, not part of a series-production electric range.'),
    ('Voltari',          'voltari',        'United States','https://voltari.com',            'active',   'electric_only',              false, null, true,  'US electric performance-boat builder; the Voltari 260 set a record for longest distance travelled by an electric boat on a single charge (91 miles, Key Largo FL to Bimini, Bahamas, at ~4.3 knots over ~20 hours).'),
    ('Blue Innovations Group', 'blue-innovations-group', 'United States','https://www.blueinnovationsgroup.com', 'active', 'electric_only', false, null, true, 'Florida (Pinellas Park) start-up founded by John Vo, former global head of manufacturing at Tesla. Announced October 2023 with the R30 as its flagship, planning a 4-model lineup: R30 (cabin day cruiser), R30G (center console), and an eventual more affordable ~25ft model (~$150,000 target). Status as of the announcement was pre-launch/reservations-open — verify current production status before treating as an established, shipping product.'),
    ('Crest Current',    'crest-current',  'United States', null,        'active',   'electric_only',              false, null, true,  'US builder of a purpose-built (not converted) all-electric pontoon boat, the Current — distinguished from pontoons that simply bolt an electric outboard onto a conventional hull.'),
    ('Pure Watercraft',  'pure-watercraft','United States','https://www.purewatercraft.com', 'active', 'electric_only',              false, null, true,  'US electric propulsion company (Pure Outboards) that also builds a purpose-built electric pontoon, the Pure Pontoon, using automotive-grade GM battery packs.'),
    ('ElectraCraft',      'electracraft',   'United States', null,        'active',   'electric_only',              false, null, true,  'US builder of small purpose-built electric boats: a mini-trimaran TR range (15-18ft) and a more traditional-looking lapstrake V-hull range (also 15-18ft), both designed for electric-only waters.'),
    ('Gosun',             'gosun',          null, null,                   'active',   'electric_only',              false, null, false, 'Builder of the Gosun Elcat, a small inflatable solar-electric catamaran. Country/full manufacturer background not confirmed in this research pass — Gosun is primarily known for solar-power consumer products outside boating.'),
    ('Sun Concept',      'sun-concept',    null,             null,                          'active',   'electric_only',              false, null, false, 'Builder of the EVO 7.0 range (Cruise and Lounge variants), listed on the Volta Yachts marketplace. Country/full manufacturer background not confirmed in this research pass — only dimensions and starting price available (no motor/battery specs).'),
    ('Silennis',         'silennis',       null,             null,                          'active',   'electric_only',              false, null, false, 'Builder of the compact S010 electric tender (3.95m), listed on the Volta Yachts marketplace. Country/full manufacturer background and technical specs not confirmed in this research pass — price on request, dimensions only.'),
    ('Helios Marine',    'helios-marine',  null,             null,                          'active',   'electric_only',              false, null, false, 'Builder of the Helios Omega and Helios Sigma electric day boats, listed on the Volta Yachts marketplace. Country/full manufacturer background and technical specs not confirmed in this research pass — dimensions and starting price only.'),
    ('Earthling',        'earthling',      null,             null,                          'active',   'electric_only',              false, null, false, 'Builder of the E-40 Power Catamaran, listed on the Volta Yachts marketplace. Country/full manufacturer background not confirmed in this research pass.'),
    ('Soel Yachts',      'soel-yachts',    'Netherlands','https://soelyachts.com',            'active',   'electric_only',              false, null, true,  'Dutch solar-electric catamaran builder with a range spanning from mid-size cruising catamarans (SoelCat 12) to superyacht-scale flagships (Senses 82) and commercial passenger shuttles (Shuttle 14).'),
    ('La Bella Verde',   'la-bella-verde', null,             null,                          'active',   'electric_only',              false, null, false, 'Builder of the LBV 35 catamaran, listed on the Volta Yachts marketplace. Country/full manufacturer background not confirmed in this research pass.'),
    ('Bord à Bord',      'bord-a-bord',    'France','https://www.bordabord.fr',            'active',   'mixed_electric_conventional', false, null, true,  'Aluminium-hull shipyard founded 2001, revitalised 2019, based in Brittany, France. Builds custom aluminium boats up to 24m for professional/commercial use (catamarans, semi-rigid RIBs, monohulls for marinas, tourism, diving, transport). Over 20 electric-propulsion boats delivered as of this research pass. Also appears on the Volta Yachts marketplace under the brand name "Naviwatt" — likely Bord à Bord''s electric-specific product line, though this naming relationship is not fully confirmed.'),
    ('Zen Yachts',       'zen-yachts',     null,             null,                          'active',   'electric_only',              false, null, false, 'Builder of the ZenRiver electric river-tourism boat, listed on the Volta Yachts marketplace. Country/full manufacturer background not confirmed in this research pass — possibly related to the "BAB Boat" branding seen alongside it, but this connection is unclear.'),
    ('Lumen Yachts',     'lumen-yachts',   'Netherlands','https://lumenyachts.com',          'active',   'electric_only',              false, null, true,  'Dutch electric yacht brand, hull built by JR Yachts (Drachten, Netherlands), naval architecture by Mulder Design and Jaap de Jonge. Flagship (and so far only) model is the LUMEN E10, using a "fast-displacement" hull design intended to give ~2-3x the range of typical electric boats at similar speed.')
on conflict (slug) do nothing;

-- =====================================================================
-- SEED DATA — Models (verified specs as of mid-2026; extend as needed)
-- =====================================================================

-- Candela C-8 — hydrofoiling electric day cruiser
-- Source: candela.com, boatingmag.com, mby.com, plugboats.com
insert into models (
    manufacturer_id, name, slug, category,
    length_m, beam_m, weight_kg, passenger_capacity,
    battery_kwh, motor_power_kw, top_speed_knots, range_nm,
    price_from_eur, description
)
select id, 'C-8', 'candela-c-8', 'day_boat',
    8.5, 2.50, 1700, 8,
    69, 75, 30, 57,
    330000,
    'Carbon-fibre hydrofoiling day cruiser. 69 kWh Polestar battery, C-Pod direct-drive motor, DC fast charging 10-80% in under 45 minutes. Longest range-at-speed of any serially produced electric boat.'
from manufacturers where slug = 'candela'
on conflict (slug) do nothing;

-- Candela Seven — lighter, smaller foiling sibling to the C-8
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    passenger_capacity, description
)
select id, 'Seven', 'candela-seven', 'day_boat', 'electric',
    6,
    'Smaller, lighter hydrofoiling sibling to the C-8, built entirely from carbon fibre (hull, deck, and deck components) drawing on techniques from fighter jet and aircraft design for high impact resistance at low weight. Detailed motor/battery/price specs not confirmed in this research pass — appears to be an earlier or entry-level Candela model rather than the current C-8 flagship.'
from manufacturers where slug = 'candela'
on conflict (slug) do nothing;

-- Strana 23 — configurable Swedish electric day boat
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    passenger_capacity, top_speed_knots, battery_kwh,
    price_from_eur, description
)
select id, 'Strana 23', 'strana-23', 'day_boat', 'electric',
    6, 15, 20,
    91000,
    'Motor size and battery capacity are configured to the buyer''s needs; base configuration uses a SeaDrive POD motor with a 20kWh lithium battery bank. Price converted from a SEK 995,000 starting price.'
from manufacturers where slug = 'strana-electric-boats'
on conflict (slug) do nothing;

-- POL Lux — Swedish solar-electric catamaran
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    description
)
select id, 'POL Lux', 'pol-lux', 'catamaran', 'electric',
    'Solar-electric catamaran with a reconfigurable open deck — sunbed, sleeping space, or open cargo area, with a roll-down canvas to enclose the whole deck. Roof-mounted solar panels charge the battery underway and while docked. Motor/battery capacity and pricing not confirmed in this research pass.'
from manufacturers where slug = 'pol-lux'
on conflict (slug) do nothing;
-- Source: mby.com, boatingmag.com, xshore.com, boattest.com
insert into models (
    manufacturer_id, name, slug, category,
    length_m, beam_m, weight_kg, passenger_capacity,
    battery_kwh, motor_power_kw, top_speed_knots, range_nm,
    price_from_eur, description
)
select id, 'Eelex 8000', 'x-shore-eelex-8000', 'day_boat',
    8.0, 2.60, 2600, 10,
    126, 170, 30, 100,
    249000,
    'Planing-hull electric day cruiser built in Stockholm. 126 kWh Kreisel dual-lithium battery, Brusa direct-drive motor, cork deck and recycled materials. Up to 100 nm range at low cruise speeds.'
from manufacturers where slug = 'x-shore'
on conflict (slug) do nothing;

-- Frauscher x Porsche 850 Fantom Air — electric day cruiser
-- Source: evmagazine.com (Porsche/Frauscher collaboration)
insert into models (
    manufacturer_id, name, slug, category,
    length_m, beam_m, passenger_capacity,
    battery_kwh, motor_power_kw, price_from_eur,
    description
)
select id, '850 Fantom Air (Porsche Edition)', 'frauscher-850-fantom-air-porsche', 'day_boat',
    8.67, 2.49, 9,
    100, 400, 562000,
    'Collaboration between Frauscher Shipyards and Porsche, based on the Frauscher 858 Fantom Air hull. Lithium-ion high-voltage battery (~100 kWh) and a permanently excited synchronous motor rated up to 400 kW. Price per user-supplied competition-landscape data (€562k); not yet cross-verified against an independent source.'
from manufacturers where slug = 'frauscher'
on conflict (slug) do nothing;

-- Silent 60 — solar-electric catamaran
-- Source: silent-yachts.com, robbreport.com, itayachtscanada.com
insert into models (
    manufacturer_id, name, slug, category,
    length_m, passenger_capacity,
    battery_kwh, motor_power_kw, top_speed_knots,
    price_from_eur, description
)
select id, 'Silent 60', 'silent-yachts-60', 'catamaran',
    18.3, 8,
    225, 400, 8,
    2750000,
    'Solar-electric bluewater catamaran, successor to the Silent 64. Twin ~200 kW electric motors, ~225 kWh lithium-ion battery bank, rooftop solar array, optional diesel range-extender generator. CE Category A (ocean-going).'
from manufacturers where slug = 'silent-yachts'
on conflict (slug) do nothing;

-- Silent 80 (Tri-Deck) — flagship solar-electric catamaran
-- Source: yachtstyle.co, silent-yachts.com, abyacht.com
insert into models (
    manufacturer_id, name, slug, category,
    length_m, passenger_capacity,
    battery_kwh, motor_power_kw, top_speed_knots,
    price_from_eur, description
)
select id, 'Silent 80 Tri-Deck', 'silent-yachts-80-tri-deck', 'catamaran',
    24.3, 9,
    429, 340, 18,
    5510000,
    'Flagship solar-electric catamaran designed with Marco Casali/MICAD. Twin 340 kW electric motors, 429 kWh lithium battery pack, diesel generators as range extenders, up to ~90 m² solar panel coverage.'
from manufacturers where slug = 'silent-yachts'
on conflict (slug) do nothing;

-- Silent 62 — mid-size solar-electric catamaran (self-sufficient cruiser)
insert into models (
    manufacturer_id, name, slug, category,
    length_m, passenger_capacity,
    description
)
select id, 'Silent 62', 'silent-yachts-62', 'catamaran',
    18.9, 8,
    'Mid-size solar-electric catamaran in the Silent range, positioned between the Silent 60 and Silent 80. Marketed for self-sufficient bluewater cruising powered primarily by rooftop solar. Detailed battery/motor specs not independently confirmed in this research pass — treat as directionally similar to the Silent 60 (twin ~200kW motors, ~225kWh battery) until sourced directly from Silent Yachts.'
from manufacturers where slug = 'silent-yachts'
on conflict (slug) do nothing;

-- 80 Sunreef Power Eco — fully electric luxury power catamaran
-- Source: sunreef-yachts.com, y.co, itboat.com
insert into models (
    manufacturer_id, name, slug, category,
    length_m, passenger_capacity,
    motor_power_kw,
    description
)
select id, '80 Sunreef Power Eco', 'sunreef-80-power-eco', 'catamaran',
    24.4, 12,
    180,
    'Fully electric luxury power catamaran with up to 200 m² of composite-integrated solar panels (~40-45.5 kWp) and twin electric motors per hull. Battery bank size is bespoke per build (custom "Sol" configuration reported at ~990 kWh with 360 kW motors). Pricing is quote-based/custom.'
from manufacturers where slug = 'sunreef-yachts'
on conflict (slug) do nothing;

-- Crooze EZ 28 — Bulgarian all-electric day boat
-- Source: croozeyachts.com (boat-specifications page), user-supplied
-- competition-landscape slide (range/capacity/price/feature set),
-- cross-checked against plugboats.com directory + horizonboatsales.co.uk
insert into models (
    manufacturer_id, name, slug, category,
    length_m, passenger_capacity,
    motor_power_kw, range_nm,
    price_from_eur, description
)
select id, 'EZ 28', 'crooze-yachts-ez28', 'day_boat',
    8.67, 12,
    207, 120,
    258000,
    'All-electric day boat, fully customizable across 6 scenarios (Commuting, Fishing, Water sports, Party, Picnic, Beach). Standard motor 207 kW (optional 270 kW). Range ~120 nm at 5 knots. Features WC, wet bar and grill, stern shower, enlarged beach area, and folding top-sides with 17 sqm floor space — a differentiator vs. Frauscher x Porsche 850 Fantom Air, ARC Boats, Axopar, and Marian in the same size class. 2025 Gussies Electric Boat Awards finalist (Concept/In Development, over 8m category).'
from manufacturers where slug = 'crooze-yachts'
on conflict (slug) do nothing;

-- Axopar AX/E 25 — electric sub-brand model (parent manufacturer is mixed)
-- Source: axopar.com, robbreport.com, mby.com, electrek.co, plugboats.com
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, battery_kwh, motor_power_kw, top_speed_knots, range_nm,
    price_from_eur, description
)
select id, 'AX/E 25', 'axopar-ax-e-25', 'day_boat', 'electric',
    7.6, 126, 225, 50, 60,
    229000,
    'Fully electric model within Axopar''s dedicated AX/E sub-brand (the rest of the Axopar range is gas/diesel — see manufacturer product_line). Evoy Storm electric outboard (225 kW nominal, up to 450 kW peak), 126 kWh battery. Won the 2023 Gussies Award for Production Electric Boats up to 8m/26ft. Available in Cross Bow and Cross Top variants.'
from manufacturers where slug = 'axopar'
on conflict (slug) do nothing;

-- Marian M 800 — flagship electric day cruiser
-- Source: marianboats.at, onboardmagazine, yachtworld.com
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, passenger_capacity,
    description
)
select id, 'M 800', 'marian-m800', 'day_boat', 'electric',
    7.90, 8,
    'Flagship hand-built electric day cruiser from Marian Boats, Lake Wolfgang, Austria. 7.90 m hull shared with the M 800 Spyder bowrider variant (10-passenger). Eight available motor/battery configurations using lithium batteries; teak deck, fully customizable finishes.'
from manufacturers where slug = 'marian-boats'
on conflict (slug) do nothing;

-- Arc One — flagship US electric cruiser (closest match to the slide's
-- "ARC Boats" row, though the slide's 8.44 m / €290k figures do not
-- exactly match any single published Arc model — verified specs below
-- are for the Arc One; treat the slide's numbers as approximate/unverified)
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, passenger_capacity,
    battery_kwh, motor_power_kw, price_from_eur, description
)
select id, 'Arc One', 'arc-boats-arc-one', 'sport', 'electric',
    7.30, 12,
    220, 373, 280000,
    'Arc''s original flagship electric cruiser (limited run, ~20 units), aluminum hull, 220 kWh battery, 500 hp (373 kW) motor, 3-5 hours mixed-use runtime. Price converted from $300,000 list (USD). Note: the competition-landscape slide lists "ARC Boats" at 8.44 m / 12 passengers / €290k, which is closest to but not an exact match for the Arc One''s published 7.3 m length — flagging as an approximate match pending direct confirmation from Arc.'
from manufacturers where slug = 'arc-boats'
on conflict (slug) do nothing;

-- Arc Sport — wake/surf-focused sibling to the Arc One
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    motor_power_kw, battery_kwh, top_speed_knots,
    price_from_eur, description
)
select id, 'Arc Sport', 'arc-boats-arc-sport', 'sport', 'electric',
    410, 225.5, 35,
    240000,
    'Wake/surf-focused sibling to the Arc One, distinct model in Arc''s electric-only range. 500-570hp (~373-425kW) motor, ~225-226kWh lithium-ion battery pack (roughly triple a Tesla Model Y''s battery capacity). Computer-controlled water ballast and actuatable tabs let users tune wave height, length, and steepness for wakeboarding/surfing. Price converted from a $258,000 starting price.'
from manufacturers where slug = 'arc-boats'
on conflict (slug) do nothing;

-- ALVA Ocean Eco 60 — first model added for this manufacturer
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m, top_speed_knots,
    price_from_eur, description
)
select id, 'Ocean Eco 60', 'alva-ocean-eco-60', 'catamaran', 'electric',
    18.4, 10.2, 20,
    2800000,
    'Solar-electric catamaran with up to 4 guest cabins, large salons, wet bar, and sunbeds for luxury cruising/entertaining. Integrated solar array up to 20kW peak across ~80 sqm of panels, enough for all-day low-speed cruising without a generator; hybrid backup extends this to transatlantic-capable range. Price range converted from a reported $2.8-4m. Note: one source lists "Stefan Frauscher" as CEO, which appears to be an editorial mix-up with Frauscher Boats (a separate, unrelated manufacturer already in this dataset) rather than ALVA''s actual leadership — flagged rather than repeated as fact.'
from manufacturers where slug = 'alva-yachts'
on conflict (slug) do nothing;
-- against manufacturer sites where possible). All manufacturers above
-- are tagged 'mixed_electric_conventional' — these are the specific
-- electric model(s) within their largely combustion-powered ranges.
-- =====================================================================

-- Alfastreet 28 Cabin — electric version of a factory petrol/electric range
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, motor_power_kw, battery_kwh, top_speed_knots, range_nm,
    price_from_eur, description
)
select id, '28 Cabin (Electric)', 'alfastreet-28-cabin-electric', 'day_boat', 'electric',
    8.61, 20, 50, 7.5, 50,
    175000,
    'Factory-fit electric version of Alfastreet''s flagship 28 Cabin, sold alongside an outboard/sterndrive petrol option on the same hull. Twin 10kW motors, twin 25kWh batteries. Built for slow-speed inland displacement cruising (5-7 knots) rather than planing performance. Price converted from ~£150,000.'
from manufacturers where slug = 'alfastreet'
on conflict (slug) do nothing;

-- Alfastreet 23 Cabin EVO — electric cuddy-cabin day boat
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    motor_power_kw, description
)
select id, '23 Cabin EVO', 'alfastreet-23-cabin-evo', 'day_boat', 'electric',
    30,
    'Cuddy-cabin electric day boat, part of the same Alfastreet range as the 28 Cabin (which spans 21-28ft, mostly available with either petrol or factory electric power). 30kW electric pod drive mounted in a hull notch; carbon-fibre hardtop with remote sliding doors; mini-galley, V-berth, and head — bridges the gap between day boats and overnight cruisers. Battery capacity not confirmed in this research pass.'
from manufacturers where slug = 'alfastreet'
on conflict (slug) do nothing;

-- Boesch 750 Portofino Deluxe — electric variant of a conventional wooden-hull range
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, motor_power_kw, battery_kwh, top_speed_knots, range_nm,
    price_from_eur, description
)
select id, '750 Portofino Deluxe (Electric)', 'boesch-750-portofino-deluxe-electric', 'day_boat', 'electric',
    7.50, 100, 71.2, 21, 14,
    336000,
    'Top-of-range electric model from Swiss wooden-boat specialist Boesch (est. 1910). Twin 50kW Piktronik motors, twin 35.6kWh batteries. Traditional mahogany laminate hull with mid-mounted motor and straight shaft, mirroring the layout of Boesch''s petrol models. Only models up to 25ft get the electric option.'
from manufacturers where slug = 'boesch-boats'
on conflict (slug) do nothing;

-- Delphia 10 — same hull, diesel engine OR electric shaft drive
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m, motor_power_kw,
    price_from_eur, description
)
select id, 'Delphia 10 (Electric)', 'delphia-10-electric', 'cruiser', 'electric',
    9.78, 3.49, 60,
    269000,
    'Vripack-designed Delphia 10, offered with a straight choice of diesel engine (up to 110hp) or electric shaft drive (40-80hp / ~30-60kW) on the same hull and three layout options (Sedan, Lounge, Lounge Top). Price shown is the base list price; electric drivetrain may carry a premium over the diesel base spec — confirm before publishing.'
from manufacturers where slug = 'delphia-yachts'
on conflict (slug) do nothing;

-- Four Winns H2e — Beneteau Group''s all-electric bowrider
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, motor_power_kw, top_speed_knots,
    description
)
select id, 'H2e', 'four-winns-h2e', 'day_boat', 'electric',
    6.70, 134, 35,
    'Billed as the first all-electric series-production bowrider. 180hp (134kW) Vision Marine electric outboard, twin 700V batteries (capacity not disclosed). Sister brand to Beneteau within Groupe Beneteau. Price and range TBC as of last update.'
from manufacturers where slug = 'four-winns'
on conflict (slug) do nothing;

-- Hinckley Dasher — legendary combustion yard''s first electric model
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, motor_power_kw, battery_kwh, top_speed_knots, range_nm,
    price_from_eur, description
)
select id, 'Dasher', 'hinckley-dasher', 'day_boat', 'electric',
    8.53, 100, 80, 23.5, 40,
    500000,
    'Hinckley''s first all-electric model (2017), built alongside its conventional jet-drive Picnic Boat range, designed from the ground up for electric propulsion by Michael Peters. Twin 80hp Torqeedo Deep Blue electric motors and TWO 40kWh BMW i3-derived lithium-ion battery packs (80kWh combined) — this figure is now supported by 2 of 3 sources checked (2018 boats.com/YachtWorld launch review and a 2025 EV Magazine feature), so it is treated as the primary spec, superseding an earlier update to this entry that had followed MBY (2023), which listed a single 40kWh pack and 2x50kW motors instead. Resin-infused carbon fibre/epoxy construction, ~6,500 lbs. Composite/titanium construction disguised as traditional teak-and-stainless — even the "teak" is hand-painted faux wood. Range ~40 miles (35nm) at 10mph (8.7kn). Price converted from $545,000 (2018) / "$500,000+" (2025 source) — broadly consistent over time. Still worth confirming the exact current-year spec directly with Hinckley before publishing, since one of three sources disagrees.'
from manufacturers where slug = 'hinckley-yachts'
on conflict (slug) do nothing;

-- Nimbus 305 Coupe E-Power — combustion design adapted to electric
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, motor_power_kw, battery_kwh, range_nm,
    price_from_eur, description
)
select id, '305 Coupe E-Power', 'nimbus-305-coupe-e-power', 'cruiser', 'electric',
    10.07, 50, 42.2, 53,
    265000,
    'Per Nimbus''s own official spec (electric boating since 2009, this configuration offered since 2015): Torqeedo Deep Blue 50i 1400rpm drive with a single 42.2kWh BMW i3 battery, chargeable in 16 hours at 230V or 8 hours at 380V. Optional upgrade to a dual 2x42.2kWh (84.4kWh total) fast-charging pack. At 5.7-knot cruise, range is 53nm; dropping to 3.7 knots extends range to 86nm. Built on Nimbus''s "Smart Speed" hull (comfortable from 0-22 knots), built to order.'
from manufacturers where slug = 'nimbus-boats'
on conflict (slug) do nothing;

-- Nimbus 305 Drophead E-Power — sister model on the same electric platform
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, motor_power_kw, battery_kwh, range_nm,
    price_from_eur, description
)
select id, '305 Drophead E-Power', 'nimbus-305-drophead-e-power', 'day_boat', 'electric',
    10.07, 50, 42.2, 53,
    255000,
    'Day-cruiser sibling to the 305 Coupe E-Power, sharing the same Smart Speed hull and Torqeedo Deep Blue 50i / BMW i3 42.2kWh electric powertrain (optional dual-pack 84.4kWh upgrade also available). Built to order.'
from manufacturers where slug = 'nimbus-boats'
on conflict (slug) do nothing;

-- Rand Source 22 — petrol/diesel base range, electric inboard option
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, motor_power_kw, top_speed_knots,
    price_from_eur, description
)
select id, 'Source 22 (Electric)', 'rand-source-22-electric', 'day_boat', 'electric',
    6.70, 170, 50,
    100000,
    'Rand''s Source 22 is available with petrol/diesel inboard or outboard engines up to 250hp, or a 170kW electric inboard for short-burst speeds to 50 knots and sustained cruising at 28 knots. Starting price shown (~€100k) is approximate for the electric configuration; the Torqeedo-outboard electric variant starts under €100,000, the more powerful inboard variant costs more — confirm current pricing before publishing.'
from manufacturers where slug = 'rand-boats'
on conflict (slug) do nothing;

-- Rand Leisure 28 — electric-configured cruiser
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    motor_power_kw, battery_kwh, top_speed_knots,
    description
)
select id, 'Leisure 28 (Electric)', 'rand-leisure-28-electric', 'day_boat', 'electric',
    155, 93, 31,
    'Electric-configured version of the Leisure 28: 155kW motor (peak 205kW), 93kWh battery bank, top speed comfortably above 30 knots with solid range. As with other RAND electric options, this is a build-to-order configuration alongside conventional petrol/diesel engines on the same hull.'
from manufacturers where slug = 'rand-boats'
on conflict (slug) do nothing;

-- Rand Escape 30 — trailerable electric-capable open powerboat
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    passenger_capacity, description
)
select id, 'Escape 30', 'rand-escape-30', 'day_boat', 'electric',
    12,
    'Compact, sporty take on the 30ft open-powerboat layout, trailerable. Up to 12 passenger capacity across 5 zones (bow area, aft triple sun lounge, dining/helm area with a toilet). Motor/battery specs for the electric configuration not confirmed in this research pass.'
from manufacturers where slug = 'rand-boats'
on conflict (slug) do nothing;

-- Rand Spirit 25 (Electric) — walk-around open day cruiser
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    passenger_capacity, top_speed_knots, price_from_eur, description
)
select id, 'Spirit 25 (Electric)', 'rand-spirit-25-electric', 'day_boat', 'electric',
    6, 33, 130900,
    'Walk-around layout with a centred pilot three-seat sofa (flip-over backrest converts to a 6-person dining area) and a triple-bed aft sun lounge. Electric configuration starts from ~€130,900 with a top speed up to 33 knots.'
from manufacturers where slug = 'rand-boats'
on conflict (slug) do nothing;
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, top_speed_knots,
    description
)
select id, 'Mana 23', 'rand-mana-23', 'day_boat', 'electric',
    7.0, 12,
    'Dedicated eco-efficiency electric model in the RAND lineup (distinct from the Source 22''s electric option), using compact but powerful electric motors for silent gliding at up to 12 knots. Positioned for calm, low-wake cruising rather than performance.'
from manufacturers where slug = 'rand-boats'
on conflict (slug) do nothing;

-- Riva El-Iseo — electric prototype of a combustion sportsboat
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, motor_power_kw, battery_kwh, top_speed_knots, range_nm,
    description
)
select id, 'El-Iseo', 'riva-el-iseo', 'day_boat', 'electric',
    8.20, 300, 150, 40, null,
    'Now in production form (debuted as a prototype at the 2023 Monaco Yacht Show, production model shown at Boot Düsseldorf), not just a prototype — update from an earlier entry in this dataset. Parker GVM310 electric motor, 250-300kW, 150kWh lithium battery, cruises at 25 knots with a 40-knot top speed, up to 10 hours cruising in economy mode. Three drive modes (Allegro/Andante/Adagio). LENGTH DISCREPANCY: one source (mennyacht.com) describes this as a "27-meter vessel," which is almost certainly a unit error (should likely read 27 feet, ~8.2m) given the Riva Iseo class this is based on is normally in the 8-9m range — kept at 8.2m here rather than propagating what looks like a typo, but flagging for direct confirmation with Riva/Ferretti Group.'
from manufacturers where slug = 'riva-yacht'
on conflict (slug) do nothing;

-- Super Air Nautique GS22E — electric version of a petrol wake boat
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, motor_power_kw, battery_kwh, top_speed_knots,
    price_from_eur, description
)
select id, 'Super Air Nautique GS22E', 'nautique-gs22e', 'sport', 'electric',
    6.70, 220, 124, 37.5,
    288000,
    'Electric version of the petrol-powered GS22 wake-surf boat, at roughly a $140,000 premium over the combustion model. Hydraulic folding wake tower, configurable running surface for ski/wakeboard/wake-surf modes. ~3 hours use per charge. Price converted from $312,952.'
from manufacturers where slug = 'nautique'
on conflict (slug) do nothing;

-- Zodiac 450 e-jet — electric jet-RIB from a conventional RIB manufacturer
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, motor_power_kw, battery_kwh, top_speed_knots, range_nm,
    price_from_eur, description
)
select id, '450 e-jet', 'zodiac-450-e-jet', 'tender', 'electric',
    4.50, 50, 40, 30, 36,
    140800,
    'Electric jet-RIB from Zodiac Nautic, primarily targeting superyacht tender use. 50kW Torqeedo Deep Blue motor with 40kWh BMW i3-derived battery driving a water jet. Also developing a smaller, more affordable eOpen electric RIB range (3.1-3.4m, from ~€25,200) alongside its conventional inflatable/RIB catalog.'
from manufacturers where slug = 'zodiac-nautic'
on conflict (slug) do nothing;

-- Frauscher 740 Mirage — electric option on a mostly-combustion model range
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, motor_power_kw, battery_kwh, top_speed_knots, range_nm,
    price_from_eur, description
)
select id, '740 Mirage (Electric)', 'frauscher-740-mirage-electric', 'day_boat', 'electric',
    7.47, 110, 80, 26, 60,
    216616,
    'Electric-motor option (Torqeedo, 60kW or 110kW) on Frauscher''s combustion-powered 740 Mirage range — the shipyard builds petrol boats up to 39ft but offers electric power on most smaller models. Distinct from the dedicated Frauscher x Porsche electric collaboration models.'
from manufacturers where slug = 'frauscher'
on conflict (slug) do nothing;

-- Greenline 40 (all-electric configuration) — vs. the same hull''s hybrid/diesel options
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, motor_power_kw, battery_kwh, top_speed_knots, range_nm,
    price_from_eur, description
)
select id, '40 (All-Electric)', 'greenline-40-electric', 'cruiser', 'electric',
    11.99, 100, 80, 11, 30,
    445000,
    'All-electric configuration of the Greenline 40, one of three propulsion choices on the same hull (all-electric / hybrid diesel-electric / conventional diesel). Twin 50kW motors, twin 40kWh batteries; range extends to ~75nm at 5 knots with the optional 4kW range extender. The Hybrid version instead pairs twin 220hp Volvo D3 diesels with electric-only cruising up to 20nm.'
from manufacturers where slug = 'greenline-yachts'
on conflict (slug) do nothing;

-- Sialia 45 Sport — entry-level electric performance day-boat
-- Source: sialia-yachts.com, plugboats.com, barcheamotore.com, boattest.com
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, passenger_capacity,
    motor_power_kw, battery_kwh, top_speed_knots, range_nm,
    description
)
select id, '45 Sport', 'sialia-45-sport', 'sport', 'electric',
    13.7, 12,
    300, 700, 43, 164,
    'Entry point to the Sialia range. Carbon fibre construction, Petestep stepped hull (up to 35% energy saving vs. conventional planing hulls). Configurable twin motors from 150-300kW per motor and battery packs of 300/500/700 kWh; figures shown are the top-spec configuration (164nm range only achieved with the optional range-extender — pure-electric range is 70+nm). DC fast charging up to 350kW. World debut at Cannes Yachting Festival 2025; won Robb Report''s 2025 Electric Boat award and the 2024 Gustave Trouvé Award. Price from ~$800,000.'
from manufacturers where slug = 'sialia-yachts'
on conflict (slug) do nothing;

-- Sialia 57 Deep Silence — original flagship, launched 2022
-- Source: nauticalexpert.com, boattest.com company background
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m, passenger_capacity,
    motor_power_kw, top_speed_knots, price_from_eur,
    description
)
select id, '57 Deep Silence', 'sialia-57-deep-silence', 'sport', 'electric',
    17.6, 4.8, 12,
    800, 32, 4000000,
    'Sialia''s original all-electric performance cruiser, launched 2022 — the model that established the shipyard. Twin 400kW motors, CE-B certified, 19-tonne displacement, cruising speed 18 knots. AC charging 22kW, DC fast charging 150kW. Uses a parallel propulsion system: a diesel engine acts as an onboard generator/backup, extending range to a claimed 250nm on a single electric charge and recharging the battery from 20-80% in about an hour — similar in concept to Silent Yachts'' range-extender pattern, so still classified as primarily electric rather than hybrid. Predates the newer 59-series and 45 Sport.'
from manufacturers where slug = 'sialia-yachts'
on conflict (slug) do nothing;

-- Sialia 59 Sport — one of three layout variants on the shared 59 platform
-- (Weekender and Runabout share the same 17.6m carbon hull and AMPROS
-- powertrain; only Sport is added here to avoid inventing per-variant
-- numbers that aren't independently published)
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, passenger_capacity,
    description
)
select id, '59 Sport', 'sialia-59-sport', 'sport', 'electric',
    17.6, 12,
    'One of three layout variants on Sialia''s shared 59-series carbon-fibre platform (alongside 59 Weekender and 59 Runabout, all 17.6m/59ft). Designed by Denis Popov Design Studio. Battery package allows up to a week at anchor before needing to recharge. Exact motor power / battery kWh / top speed are not independently published per variant — treat as similar order of magnitude to the 57 Deep Silence (800kW combined) until confirmed directly with the shipyard before publishing on a spec-comparison page.'
from manufacturers where slug = 'sialia-yachts'
on conflict (slug) do nothing;

-- Sialia 80 Explorer — flagship long-range explorer, aluminum hull
-- Source: sialia-yachts.com, elitetraveler.com, superyachttimes.com, yachtbuyer.com
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m, passenger_capacity,
    motor_power_kw, battery_kwh, top_speed_knots, range_nm,
    description
)
select id, '80 Explorer', 'sialia-80-explorer', 'cruiser', 'electric',
    26.6, 8.5, 12,
    800, 800, 11, 3000,
    'Flagship long-range explorer, developed with Dutch naval architecture studio Vripack. Aluminum hull construction. Twin 400kW electric motors plus two variable-RPM range extenders for redundancy. 4 guest cabins + 2 crew berths. Master cabin has direct beach-club access. Displacement-speed vessel (11+ knots) prioritizing range (3,000+ nm) over top speed, unlike the sportier 45/57/59 models.'
from manufacturers where slug = 'sialia-yachts'
on conflict (slug) do nothing;

-- Vita Power Tridente — Maserati collaboration, luxury electric day boat
-- Source: yachtworld.com, plugboats.com, vita-power.com
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, passenger_capacity,
    motor_power_kw, battery_kwh, top_speed_knots, range_nm,
    description
)
select id, 'Tridente (Maserati Collaboration)', 'vita-power-tridente-maserati', 'day_boat', 'electric',
    10.5, 8,
    447, 252, 40, 50,
    'Co-branded collaboration between Vita Power and Maserati — extends Maserati''s automotive electrification strategy to the water. Carbon fibre hull built by Maine-based Hodgdon Yachts; rose-gold livery with Maserati Trident branding. 600bhp (~447kW) motor, 252kWh Vita Power battery, cruising speed 25 knots. Recharges 10-90% in under an hour. Believed to share its core platform with Vita''s own Lion day boat (also 10.5m, similar performance), with Maserati styling and branding on top. Price not publicly disclosed.'
from manufacturers where slug = 'vita-power'
on conflict (slug) do nothing;

-- Vita Seal — production electric RIB
-- Source: pbo.co.uk, vita-power.com, plugboats.com
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, motor_power_kw, battery_kwh, top_speed_knots,
    price_from_eur, description
)
select id, 'Seal', 'vita-power-seal', 'tender', 'electric',
    7.2, 95, 126, 30,
    157000,
    'Vita''s first RIB designed and engineered from the ground up around its own electric powertrain (launched 2021), rather than a converted combustion hull. Aluminium hull, built in Serbia. 95kW continuous / 140kW peak motor, available with single (63kWh) or dual (126kWh) battery pack. DC supercharge 10-90% in under an hour. Sold to San Diego Yacht Club, City of Newport Beach, and used at the Paris 2024 Olympics. Price converted from a starting point of ~£135,000 (GBP); this figure is shared/approximate across Seal and SeaDog per the source.'
from manufacturers where slug = 'vita-power'
on conflict (slug) do nothing;

-- Vita SeaDog — smaller electric RIB, commercial/marina use
-- Source: pbo.co.uk, vita-power.com, plugboats.com
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, motor_power_kw, battery_kwh, top_speed_knots,
    price_from_eur, description
)
select id, 'SeaDog', 'vita-power-seadog', 'tender', 'electric',
    5.8, 140, 63, 30,
    157000,
    'Compact all-electric RIB aimed at ports, marinas and harbour work. Aluminium hull, built in Serbia. Single 63kWh battery pack, up to 140kW peak (V150 powertrain). Top speed over 25 knots per Vita''s own marketing, up to 30 knots per independent test coverage. Price converted from a starting point of ~£135,000 (GBP), shared/approximate across Seal and SeaDog per the source.'
from manufacturers where slug = 'vita-power'
on conflict (slug) do nothing;

-- Vita Lion — Vita Power's own premium production day boat (base platform
-- believed shared with the Maserati Tridente)
-- Source: robbreport.com, vita-power.com
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, motor_power_kw, battery_kwh, top_speed_knots,
    price_from_eur, description
)
select id, 'Lion', 'vita-power-lion', 'day_boat', 'electric',
    10.67, 300, 235, 35,
    900000,
    'Vita''s first premium production electric day boat, first built at Hodgdon''s Maine shipyard (the same yard that builds the carbon hull for the Maserati Tridente). Per MBY (2023): twin 150kW motors (300kW combined) driving a single Mercury Bravo sterndrive, 235kWh battery, top speed ~35 knots, cruising 90 minutes at 22 knots or ~10 hours at 6-7 knots. Believed to share its core platform with the Maserati Tridente collaboration (same ~10.5m length, similar cruise/top speed). Price converted from a £750,000 (ex VAT) starting price. DATA CONFLICT: a separate Robb Report source instead cites 590hp (~440kW) and a $1.5m base price — see the powertrain table note for detail; confirm current spec/pricing with Vita Power before publishing.'
from manufacturers where slug = 'vita-power'
on conflict (slug) do nothing;

-- TYDE / BMW "THE ICON" — foiling electric passenger trimaran
-- Source: yachtworld.com
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m,
    motor_power_kw, battery_kwh, top_speed_knots, range_nm,
    description
)
select id, 'THE ICON', 'tyde-the-icon', 'other', 'electric',
    13.16, 4.5,
    200, 240, 30, 50,
    'Collaboration between BMW and German foiling startup TYDE — a reverse-bow, glass-hulled foiling trimaran aimed at B2B luxury ferry/shuttle use (resort transfers, airport-to-harbour) rather than private ownership. Lifts onto its hydrofoils at 18 knots. Twin 100kW Torqeedo motors, six BMW i3-derived battery modules totalling 240kWh. Interior styled by BMW with a 32-inch touchscreen (BMW Operating System 8) and a Hans Zimmer-composed onboard soundscape. Category set to ''other'' rather than a standard day-boat/tender type given its unconventional foiling-ferry design and B2B commercial positioning.'
from manufacturers where slug = 'tyde'
on conflict (slug) do nothing;

-- Enata Marine Foiler — diesel-electric hybrid foiling sportboat
-- IMPORTANT: hybrid_electric, NOT pure electric — twin diesels drive
-- generators; electric motors drive the props. Pure-electric mode is
-- only available for 10 minutes at 10 knots (marina/close-quarters use).
-- Source: yachtworld.com
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, passenger_capacity,
    motor_power_kw, top_speed_knots, range_nm,
    price_from_eur, description
)
select id, 'Foiler', 'enata-marine-foiler', 'sport', 'hybrid_electric',
    9.75, 8,
    448, 40, 113,
    990000,
    'First fully production foiling powerboat, built by UAE-based Enata Marine, carbon fibre construction. Diesel-electric hybrid: twin 300hp diesel engines drive generators, which power twin electric motors turning the props. Pure-electric mode available for only 10 minutes at 10 knots (marina manoeuvring) — this is NOT a pure-electric boat despite silent-running foiling capability. Takeoff onto foils at 17 knots; foiling reduces fuel consumption 20-50% and generates a claimed 3x less wake than a conventional boat of the same size above 18 knots. Range ~130 miles (113nm) at 30 knots under hybrid power. IYC is the exclusive global sales representative.'
from manufacturers where slug = 'enata-marine'
on conflict (slug) do nothing;

-- =====================================================================
-- SEED DATA — Models from electrifiedmarina.com dealer catalog research
-- =====================================================================

-- Flux Marine Scout 215 Dorado — electric package on a Scout Boats hull
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m, passenger_capacity,
    motor_power_kw, battery_kwh, top_speed_knots, range_nm,
    description
)
select id, 'Scout 215 Dorado', 'flux-marine-scout-215-dorado', 'day_boat', 'electric',
    6.55, 2.57, 9,
    112, 84, 27.8, 26,
    'Dual-console bowrider on a Scout Boats 215 hull (Scout is a conventional South Carolina/North Carolina builder), fitted with the Flux Marine 100 electric outboard (150hp peak). Fiberglass hull, Permateak deck. Part of a wider Flux/Scout partnership that also includes the Scout 215 XSF center console sport-fishing variant on the same electric platform.'
from manufacturers where slug = 'flux-marine'
on conflict (slug) do nothing;

-- Flux Marine Highfield Sport 660 — electric package on a Highfield RIB hull
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    passenger_capacity,
    motor_power_kw, battery_kwh, top_speed_knots, range_nm,
    description
)
select id, 'Highfield Sport 660', 'flux-marine-highfield-sport-660', 'tender', 'electric',
    14,
    86, 84, 29.5, 22,
    'Rigid inflatable boat (RIB) built on Highfield''s aluminium-hull Sport 660 platform (Highfield is a conventional international RIB manufacturer), fitted with a Flux Marine electric outboard (100-115hp equivalent, up to 150hp peak acceleration). Hypalon tubes, Garmin display, hydraulic steering.'
from manufacturers where slug = 'flux-marine'
on conflict (slug) do nothing;

-- Magonis Wave e-550 — flagship electric day boat
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m, passenger_capacity,
    battery_kwh, top_speed_knots, range_nm,
    price_from_eur, description
)
select id, 'Wave e-550', 'magonis-wave-e550', 'day_boat', 'electric',
    5.50, 1.98, 6,
    28.65, 22, 30,
    33485,
    'Lightweight vacuum-infused composite hull (Light X Pro construction, ~335-435kg dry depending on configuration), sold with a choice of four electric outboards: two Torqeedo Cruise options (4kW/10kW) or two Mag Power options (18kW/30kW), each paired with a different battery capacity (5-28.65kWh). Price ranges from €33,485 (4kW Torqeedo) to €68,900 (30kW Mag Power) including VAT. 2023 Gussies Award finalist.'
from manufacturers where slug = 'magonis'
on conflict (slug) do nothing;

-- Chris-Craft Launch 25 GTe — concept electric bowrider (NOT yet in production)
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, motor_power_kw, battery_kwh, top_speed_knots,
    description
)
select id, 'Launch 25 GTe (Concept)', 'chris-craft-launch-25-gte', 'day_boat', 'electric',
    7.81, 313, 133, 43,
    'CONCEPT boat, not yet commercially available — unveiled at the 2023 Miami International Boat Show, built by Chris-Craft''s engineering team with Winnebago Industries'' Advanced Technology Group and EVOA Propulsion. Same layout/dimensions as the combustion Launch 25, but 3,525kg vs 2,753kg due to the battery bank. 420hp (~313kW) EVOA electric sterndrive, 133kWh battery. ~2 hours runtime at speed. Chris-Craft states further testing is needed before any commercial version — do not list a price or availability date.'
from manufacturers where slug = 'chris-craft'
on conflict (slug) do nothing;

-- Elvene Amber — solar-electric center console / day cruiser hybrid
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m, passenger_capacity,
    battery_kwh, top_speed_knots, range_nm,
    price_from_eur, description
)
select id, 'Amber', 'elvene-amber', 'day_boat', 'electric',
    6.2, 2.1, 7,
    22, 15, 100,
    90000,
    'Solar-electric flagship combining center-console offshore capability with day-cruiser overnight comfort (2-person cuddy cabin). Integrated walkable solar panels (1,300-2,000W). Twin BLDC outboard motors (48V), fiberglass hull, ~750kg. In full sunlight, range at 5 knots is effectively unlimited (zero net battery draw); on battery alone in darkness, ~100nm at 5 knots. Price from €90,000 ex. EU VAT.'
from manufacturers where slug = 'elvene'
on conflict (slug) do nothing;

-- Elvene Amy — faster solar-electric model (2026 debut)
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    motor_power_kw, top_speed_knots, range_nm,
    description
)
select id, 'Amy', 'elvene-amy', 'day_boat', 'electric',
    50, 30, 35,
    'Higher-performance sibling to the Amber, debuting at Nice Boating Tomorrow 2026. Marketed as one of the fastest solar-electric production boats. 50kW ARIES outboard drive from German propulsion partner Molabo (48V, "safe-to-touch" system). Range figures apply at 20-knot cruise; low-speed operation extends range further via solar assist.'
from manufacturers where slug = 'elvene'
on conflict (slug) do nothing;

-- Princecraft Brio e-17 — dedicated electric pontoon within a conventional range
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, passenger_capacity,
    description
)
select id, 'Brio e-17', 'princecraft-brio-e17', 'day_boat', 'electric',
    5.2, 5,
    'Entry-level all-electric pontoon within Princecraft''s otherwise conventional (gas outboard) pontoon range. Aluminium hull, CE Category C, lightweight (~592kg) design built specifically to accommodate battery weight. Powered by a Torqeedo outboard (specific model has varied by year, e.g. 2.0R/4.0R or 3.0RL/6.0RL/12.0RL); capacity 5 (7 in the US market). Entry price around $13,000 base.'
from manufacturers where slug = 'princecraft'
on conflict (slug) do nothing;

-- Volare Boats Artemis 23 — purpose-built electric semi-foiling catamaran
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m, passenger_capacity,
    motor_power_kw, top_speed_knots, range_nm,
    description
)
select id, 'Artemis 23', 'volare-artemis-23', 'catamaran', 'electric',
    7.0, 2.39, 8,
    50, 26, 35,
    'Semi-foiling electric catamaran, purpose-built (not a converted combustion hull) by a team of former Scout Boats engineers/executives. Twin 25kW (66hp-equivalent) direct-drive electric motors on 48V systems, each pod rotating 90° for Optimus 360 joystick maneuvering. Semi-foiling assist between the hulls reduces drag. Prepreg carbon fibre T-top.'
from manufacturers where slug = 'volare-boats'
on conflict (slug) do nothing;

-- NovaLuxe Orphie 39 — electric trimaran
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m,
    description
)
select id, 'Orphie 39', 'novaluxe-orphie-39', 'catamaran', 'electric',
    11.9,
    'Described as NovaLuxe''s "only electric trimaran" — implying other NovaLuxe models are not necessarily pure-electric (hence the manufacturer is tagged mixed). Trampoline-style foredeck, carbon-fibre crossbeams, solar integration, minimalist cabin. Positioned for day cruising and eco-touring rather than full-time liveaboard use. Detailed motor/battery specs not independently confirmed in this research pass.'
from manufacturers where slug = 'novaluxe'
on conflict (slug) do nothing;

-- Vision Marine V24 — electric pontoon
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, passenger_capacity,
    motor_power_kw, battery_kwh, range_nm,
    price_from_eur, description
)
select id, 'V24', 'vision-marine-v24', 'day_boat', 'electric',
    7.52, 12,
    134, 43, 40,
    92000,
    'Electric pontoon powered by Vision''s E-Motion 180E high-voltage powertrain (180hp equivalent). Standard 43kWh battery gives ~40nm range; optional second pack (86kWh total) extends range to ~90nm. Onboard charger supports 120-240V (30-50A). Price converted from $99,995 (base config).'
from manufacturers where slug = 'vision-marine'
on conflict (slug) do nothing;

-- Vision Marine V30 — larger electric pontoon
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m, passenger_capacity,
    motor_power_kw, battery_kwh, range_nm,
    price_from_eur, description
)
select id, 'V30', 'vision-marine-v30', 'day_boat', 'electric',
    9.14, 2.62, 15,
    134, 43, 40,
    129000,
    'Larger sibling to the V24, same E-Motion 180E powertrain and dual battery-pack range options (43kWh/~40nm or 86kWh/~90nm). Added features vs. V24: 4x6.5" interior speakers, cool-touch seating. Price converted from $139,995 (base config).'
from manufacturers where slug = 'vision-marine'
on conflict (slug) do nothing;

-- Vision Marine Phantom — compact rotomolded electric boat
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, passenger_capacity,
    description
)
select id, 'Phantom', 'vision-marine-phantom', 'day_boat', 'electric',
    5.03, 10,
    'Compact 100%-plastic rotomolded electric boat, part of Vision''s lower-cost lineup. Detailed motor/battery specs not independently confirmed in this research pass — Vision''s marketing lists this line at "6hp," which appears inconsistent with other Vision models and needs direct confirmation before publishing.'
from manufacturers where slug = 'vision-marine'
on conflict (slug) do nothing;

-- =====================================================================
-- SEED DATA — Models from MBY "A-Z of electric boats" (2023)
-- IMPORTANT: this source is dated September 2023. Specs and prices below
-- reflect that point in time; several fields conflict with newer sources
-- already in this dataset (see notes on hinckley-dasher and
-- vita-power-lion powertrain rows for specific examples). Re-verify
-- anything price-sensitive before publishing.
-- =====================================================================

-- Cosmopolitan 66 — large solar-electric catamaran with generator backup
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m,
    motor_power_kw, battery_kwh,
    top_speed_knots,
    description
)
select id, '66', 'cosmopolitan-yachts-66', 'catamaran', 'electric',
    20.1, 10.67,
    360, 450,
    20,
    'All-aluminium solar/electric catamaran with generous interior volume from a 10.67m beam. Combines battery, solar panel, and ICE-generator power sources — the generator appears to function as a range-extender rather than a standalone conventional propulsion mode, similar to the Silent Yachts pattern. Range and price not disclosed as of the 2023 source.'
from manufacturers where slug = 'cosmopolitan-yachts'
on conflict (slug) do nothing;

-- Duffy Sun Cruiser 22 — best-selling electric boat in the world
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, passenger_capacity,
    motor_power_kw, top_speed_knots, range_nm,
    price_from_eur, description
)
select id, 'Sun Cruiser 22', 'duffy-sun-cruiser-22', 'day_boat', 'electric',
    6.7, 12,
    50, 5.5, 40,
    43000,
    'Slow-speed (5.5-knot top speed) bay/lake cruiser, the best-selling electric boat model in history. 48-volt system, bank of 16 six-volt batteries. Patented Power Rudder integrates the motor, rudder, and 4-blade prop into a single assembly that rotates ~90° for easy docking. Price converted from a $61,500 starting price (2023).'
from manufacturers where slug = 'duffy'
on conflict (slug) do nothing;

-- Hermes Speedster E — Porsche 356-inspired retro electric roadster-boat
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m,
    motor_power_kw, battery_kwh, top_speed_knots, range_nm,
    price_from_eur, description
)
select id, 'Speedster E', 'hermes-speedster-e', 'day_boat', 'electric',
    6.7,
    100, 30, 30, 50,
    186000,
    'Greek-built retro roadster-styled runabout inspired by the Porsche 356 Speedster, sold in the UK via Seven Seas Yachts since 2017; the combustion version uses a 115hp Rotax engine, with the Speedster E electric option added more recently. Range figure (50nm) is at 5 knots displacement speed, not planing speed. Price converted from $269,000 (2023).'
from manufacturers where slug = 'hermes-seven-seas'
on conflict (slug) do nothing;

-- Mantaray M24 — mechanically foiling runabout
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m,
    motor_power_kw, battery_kwh, top_speed_knots, range_nm,
    description
)
select id, 'M24', 'mantaray-m24', 'sport', 'electric',
    5.50,
    48, 26, 30, 60,
    'Mannerfelt-designed foiling runabout using a patented mechanical hydrofoil system (Dynamic Wing Technology) with a retractable bow T-foil and amidships H-foil that self-stabilise without the electronic foil-control system used by rivals like Candela. Price not disclosed as of the 2023 source.'
from manufacturers where slug = 'mantaray'
on conflict (slug) do nothing;

-- Mayla FortyFour — ultra-high-performance carbon electric/hybrid boat
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m,
    motor_power_kw, battery_kwh, top_speed_knots, range_nm,
    description
)
select id, 'FortyFour', 'mayla-fortyfour', 'sport', 'electric',
    13.4, 3.0,
    800, 500, 70, 70,
    'Ultralight carbon-fibre performance boat on a Petestep hull, targeting 70+ knot top speeds via twin 400-800kW dual-core motors (up to 2,150hp combined) driving tunnel-mounted surface drives. All-electric version uses a 500kWh battery for ~70nm range; a hybrid version pairs a smaller 400kWh battery with a 400hp diesel generator for up to 270nm range at 30 knots. Price not disclosed as of the 2023 source.'
from manufacturers where slug = 'mayla-yachts'
on conflict (slug) do nothing;

-- Navier N30 — Silicon Valley-backed foiling electric dayboat
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m,
    motor_power_kw, battery_kwh, top_speed_knots, range_nm,
    price_from_eur, description
)
select id, 'N30', 'navier-n30', 'day_boat', 'electric',
    9.1, 2.6,
    180, 80, 35, 75,
    276000,
    'Carbon-hulled foiling dayboat with retractable foils, built at the Lyman-Morse shipyard in Maine. Available as a Cabin or open Hardtop version, both with a self-docking feature. Twin 90kW motors, 80kWh battery. Claimed to be the longest-range 30ft electric boat in its class (~75nm at 20 knots). 2023 production run reported sold out at time of publication. Price converted from a $300,000 starting price.'
from manufacturers where slug = 'navier'
on conflict (slug) do nothing;

-- Nero 777 Evolution — Italian-designed, German-built performance day boat
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m,
    motor_power_kw, battery_kwh, top_speed_knots, range_nm,
    price_from_eur, description
)
select id, '777 Evolution', 'nero-777-evolution', 'day_boat', 'electric',
    7.77, 2.63,
    300, 126, 50, 108,
    265000,
    'Petestep-hulled performance day boat designed in Italy, built in Germany. Offered with a choice of five Evoy propulsion configurations from 60kW up to 300kW (the latter giving 50+ knot top speed). Fold-down beach-club-style balconies. Range figure (108nm) applies at a 5-knot low-speed setting, not top speed. Price converted from a €287,500 starting price.'
from manufacturers where slug = 'nero-boats'
on conflict (slug) do nothing;

-- Optima E10 — stabilised-monohull long-range electric cruiser
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m,
    motor_power_kw, battery_kwh, top_speed_knots, range_nm,
    price_from_eur, description
)
select id, 'E10', 'optima-e10', 'day_boat', 'electric',
    11.0,
    40, 120, 15, 200,
    467000,
    'Stabilised monohull with slender outrigger side-hulls forming drag-reducing tunnels underneath — designed for efficient displacement-speed cruising (14-15 knots) rather than planing performance. Twin 63kWh Kreisel battery packs (120kWh total), single 40kW Rad Propulsion motor (~54hp equivalent). Long range (200nm) at 6 knots. Price converted from a £400,000 starting price.'
from manufacturers where slug = 'optima-yachts'
on conflict (slug) do nothing;

-- Pixii SP800 — British aluminium jet-drive electric sportsboat
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m,
    motor_power_kw, battery_kwh, top_speed_knots, range_nm,
    price_from_eur, description
)
select id, 'SP800', 'pixii-sp800', 'sport', 'electric',
    7.5,
    50, 150, 40, 100,
    133000,
    'Aluminium-hulled electric sportsboat under development on the Isle of Wight (UK) as of the 2023 source, with either one or two electric motors linked to a jet drive and a claimed class-leading 150kWh battery pack. Optional remote-anchoring system allows the boat to be driven off a beach unmanned. Price converted from a £114,000 starting price.'
from manufacturers where slug = 'pixii'
on conflict (slug) do nothing;

-- Persico Zagato 100.2 — Italian-automotive-design electric jet boat
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m,
    motor_power_kw, battery_kwh, top_speed_knots, range_nm,
    description
)
select id, '100.2', 'persico-zagato-100-2', 'sport', 'electric',
    7.9,
    205, 166, 43.5, 47,
    'Collaboration between performance-boat specialist Persico and automotive design house Zagato, built around a steerable electric waterjet pod (Sealence DeepSpeed 420 azipod) rather than a conventional prop or sterndrive. Reverse bow, wraparound windshield, aft sunpad. Range figure (47nm) applies at a 24-knot cruise setting. Price not disclosed as of the 2023 source.'
from manufacturers where slug = 'persico-zagato'
on conflict (slug) do nothing;

-- Q-Yachts Q30 — Finnish silent-cruising electric day boat
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m,
    motor_power_kw, battery_kwh, top_speed_knots, range_nm,
    price_from_eur, description
)
select id, 'Q30', 'q-yachts-q30', 'day_boat', 'electric',
    9.3, 2.2,
    24, 30, 14, 54,
    183000,
    'Displacement-hull design based on a 1920s smuggler-boat shape, optimised for energy efficiency. Twin 12kW (continuous) POD drives, separate batteries per motor for redundancy, 30kWh lithium-ion total, charges from standard 230V shore power. Three speed/range profiles: silent cruising at 6kn gives 54nm range; 9kn cruising gives 42nm; 14kn max speed gives 22nm (usable for ~1.5 hours). 1.6-tonne displacement.'
from manufacturers where slug = 'q-yachts'
on conflict (slug) do nothing;

-- Ripple Boats 10m Day Cruiser — Norwegian debut model
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m,
    motor_power_kw, battery_kwh, range_nm,
    description
)
select id, '10m Day Cruiser', 'ripple-boats-10m-day-cruiser', 'day_boat', 'electric',
    10.0, 3.2,
    186, 190, 45,
    'Debut model from Norwegian start-up Ripple Boats (Frydenbø Marine + Pascal Technologies), designed by Thorup Design. Extendable hard-top bimini with inset glazing, folding balconies. Twin 93kW motors, 190kWh battery. Company plans a wider 6-11m electric range if this model succeeds. Price not disclosed as of the 2023 source.'
from manufacturers where slug = 'ripple-boats'
on conflict (slug) do nothing;

-- RS Pulse 63 — first British production-ready electric planing RIB
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m,
    motor_power_kw, battery_kwh, top_speed_knots, range_nm,
    price_from_eur, description
)
select id, 'Pulse 63', 'rs-sailing-pulse-63', 'tender', 'electric',
    6.30,
    40, 46, 23, 100,
    97000,
    'First production-ready electric planing RIB from a British yard — RS Sailing, better known for its sailing dinghy range. Hull design by Jo Richards (of RS''s dinghy fame), styling by Design Unlimited. RAD Propulsion motor system (safer/more efficient than an exposed propeller per the manufacturer), Hyperdrive battery pack, optional extra 23kWh pack for extended range. Price converted from a £82,800 starting price.'
from manufacturers where slug = 'rs-sailing'
on conflict (slug) do nothing;

-- SAY Carbon Yachts 29 E — electric version of a combustion carbon speedboat
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m,
    motor_power_kw, battery_kwh, top_speed_knots, range_nm,
    price_from_eur, description
)
select id, '29 E', 'say-carbon-29e', 'sport', 'electric',
    8.85,
    360, 120, 48, 25,
    396460,
    'Electric version of SAY Carbon''s combustion-powered 29 model — German ultralight carbon-fibre construction (~400kg hull, under 2 tonnes all-up incl. battery). Kreisel Electric drivetrain, 360kW. Held the record (as of 2018/2021 sources) for fastest series-production electric boat in the 8-10m class at ~48 knots. Wave-cutter bow and side-wings for stability at high speed. Built-in 22kW charger gives a full recharge in 6 hours.'
from manufacturers where slug = 'say-carbon-yachts'
on conflict (slug) do nothing;

-- SpiritBARTech 35EF — one-off electric foiling chase boat
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, top_speed_knots, range_nm,
    description
)
select id, 'BARTech 35EF', 'spirit-yachts-bartech-35ef', 'sport', 'electric',
    10.6, 28, 100,
    'One-off electric foiler commissioned as a chase-boat/tender for the owner of Spirit Yachts'' 111ft super-sloop sailing yacht Geist, designed by Spirit CEO Sean McMillan (inspiration drawn from a 1920s Gold Cup-winning hydroplane, Baby Bootlegger). Set an electric-boat record for fastest circumnavigation of the Isle of Wight (~23 knots average, under 2 hours). Motor/battery details not disclosed; price available on application only.'
from manufacturers where slug = 'spirit-yachts'
on conflict (slug) do nothing;

-- Voltari 260 — record-distance electric performance boat
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m,
    motor_power_kw, battery_kwh, top_speed_knots, range_nm,
    price_from_eur, description
)
select id, '260', 'voltari-260', 'sport', 'electric',
    8.6,
    551, 142, 52, 79,
    415000,
    'Set the record for longest distance travelled by an electric boat on a single charge (91 miles / ~79nm, Key Largo, Florida to Bimini, Bahamas, crossing the Gulf Stream, averaging ~4.3 knots over ~20 hours). At full performance, 551kW (740hp) motor and 142kWh battery give a 52-knot top speed. Price converted from a $450,000 starting price.'
from manufacturers where slug = 'voltari'
on conflict (slug) do nothing;

-- Blue Innovations Group R30 — flagship electric day cruiser (announced 2023)
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m, passenger_capacity,
    motor_power_kw, battery_kwh, top_speed_knots,
    price_from_eur, description
)
select id, 'R30', 'blue-innovations-group-r30', 'day_boat', 'electric',
    9.14, 3.0, 12,
    596, 221, 39,
    280000,
    'Flagship day cruiser designed by ex-Tesla manufacturing exec John Vo, announced October 2023 (public launch event planned for December 2023 in St. Petersburg, Florida; deliveries originally targeted Q3 2024 — verify actual production status before publishing). Twin 298kW motors (596kW/800hp combined), 221kWh battery, DC fast-charge to 80% in 45 minutes, ~8hr runtime. Air-conditioned cabin with convertible dinette/berth, kitchenette, head with bidet, roof + slide-out solar panels, fold-down transom walls forming a beach-club area. Price converted from an announced $300,000 target.'
from manufacturers where slug = 'blue-innovations-group'
on conflict (slug) do nothing;

-- Crest Current — purpose-built electric pontoon
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, description
)
select id, 'Current', 'crest-current-model', 'day_boat', 'electric',
    6.1,
    'Purpose-built (not converted) all-electric pontoon, roughly 20ft, with forward couches and an L-shaped aft lounge. Likely uses an ePropulsion Navy Evo outboard (3.0 or 6.0, 6-9.9hp equivalent) giving 13-18 hours runtime at cruise speed, with a standard 110V charger (~9hr charge) — spec attribution to this specific model is not fully confirmed, so treat these figures as indicative rather than certain.'
from manufacturers where slug = 'crest-current'
on conflict (slug) do nothing;

-- NovaLuxe ELIGHT 40 — smallest model in the NovaLuxe range (despite the "40" name)
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, top_speed_knots, description
)
select id, 'ELIGHT 40', 'novaluxe-elight-40', 'catamaran', 'electric',
    6.4, 10,
    'Smallest power catamaran in the NovaLuxe range at 21ft (the range goes up to 70ft) — note the "40" in the name does not refer to length. 6kWh solar array feeding twin 48V electric inboards; solar-only cruising up to 5 knots, top speed 10 knots, LiFePO4 battery providing up to 10 hours without solar input. Enclosed cabins in each hull, enclosed head, open forward saloon with a trampoline foredeck.'
from manufacturers where slug = 'novaluxe'
on conflict (slug) do nothing;

-- Pure Watercraft Pure Pontoon
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, motor_power_kw, battery_kwh, top_speed_knots, range_nm,
    description
)
select id, 'Pure Pontoon', 'pure-watercraft-pure-pontoon', 'day_boat', 'electric',
    7.85, 37, 65, 21.7, 26,
    'Purpose-built electric pontoon (not a converted hull), available with single or twin Pure Outboards (up to ~50hp each). 65kWh automotive-grade GM battery pack. Twin-motor top speed up to ~25mph (~21.7kn); range up to 30 miles (~26nm) at top speed or 185 miles (~161nm) at a gentle 5mph. Optional Level II charger recharges half-to-full in 4 hours.'
from manufacturers where slug = 'pure-watercraft'
on conflict (slug) do nothing;

-- Vision Marine WX 20 — tri-toon pontoon, single outboard
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, description
)
select id, 'WX 20', 'vision-marine-wx-20', 'day_boat', 'electric',
    6.1,
    'Tri-toon pontoon powered by a single ePropulsion 3.0 outboard, paired with 1-3 lithium-ion battery packs (3kWh each). Top speed around 5mph; runtime 3-10 hours depending on battery configuration. Adapted to a third-party motor line rather than Vision''s own E-Motion powertrain, but sold electric-only (no gas option).'
from manufacturers where slug = 'vision-marine'
on conflict (slug) do nothing;

-- Vision Marine WX 23 — larger tri-toon pontoon, twin outboards
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, description
)
select id, 'WX 23', 'vision-marine-wx-23', 'day_boat', 'electric',
    7.0,
    'Larger sibling to the WX 20, with twin ePropulsion 3.0 outboards instead of one, and the same 1-3x 3kWh lithium-ion battery pack options. Top speed around 5mph.'
from manufacturers where slug = 'vision-marine'
on conflict (slug) do nothing;

-- ElectraCraft TR range (152 and siblings) — mini-trimaran electric cruisers
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, top_speed_knots,
    description
)
select id, 'TR 152', 'electracraft-tr-152', 'day_boat', 'electric',
    4.57, 5.2,
    'One of three sizes (15-18ft) in ElectraCraft''s mini-trimaran TR range, designed for electric-only waterways. Full canvas or fiberglass hard top, solar-panel compatible, center-facing seating from bow to stern. Inboard electric motor with V-drive. Top speed ~6mph (~5.2kn), cruise ~4mph (~3.5kn), ~3.5 hours runtime at full speed. ElectraCraft also offers a more traditional-looking 15-18ft lapstrake V-hull electric range alongside the TR trimarans.'
from manufacturers where slug = 'electracraft'
on conflict (slug) do nothing;

-- Gosun Elcat — small inflatable solar-electric catamaran
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    battery_kwh, description
)
select id, 'Elcat', 'gosun-elcat', 'tender', 'electric',
    1.276,
    'Small inflatable solar-powered catamaran, among the most compact electric boats on the market. Powered by an ePropel Spirit 1.0 Plus motor (~3hp equivalent), 1,276Wh lithium-ion battery rechargeable via a pair of 100W solar panels.'
from manufacturers where slug = 'gosun'
on conflict (slug) do nothing;

-- Candela P-12 — commercial hydrofoil passenger ferry
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    passenger_capacity, description
)
select id, 'P-12', 'candela-p-12', 'other', 'electric',
    30,
    'Commercial hydrofoiling passenger ferry, extending Candela''s foiling technology from recreational day boats (C-8) into public transit. Already in commercial service (e.g. Stockholm public transit trial). Detailed motor/battery specs not confirmed in this research pass — category set to "other" given its commercial-transit rather than recreational purpose.'
from manufacturers where slug = 'candela'
on conflict (slug) do nothing;

-- =====================================================================
-- SEED DATA — Additional models from Volta Yachts marketplace listing
-- (voltayachts.com/en/boat-type/open-day-cruisers) — dimensions and
-- starting prices only; no motor/battery specs were shown on this
-- listing page. Treat these as commercially-listed price/size data,
-- not full technical specifications.
-- =====================================================================

-- Sun Concept EVO 7.0 Cruise
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m, price_from_eur, description
)
select id, 'EVO 7.0 Cruise', 'sun-concept-evo-7-0-cruise', 'day_boat', 'electric',
    6.98, 2.4, 81570,
    'Listed on the Volta Yachts marketplace (Barcelona). Draft 0.4m. Motor/battery specs not disclosed on the listing.'
from manufacturers where slug = 'sun-concept'
on conflict (slug) do nothing;

-- Sun Concept EVO 7.0 Lounge
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m, price_from_eur, description
)
select id, 'EVO 7.0 Lounge', 'sun-concept-evo-7-0-lounge', 'day_boat', 'electric',
    7.1, 2.4, 74825,
    'Lounge-layout sibling to the EVO 7.0 Cruise. Draft 0.4m. Motor/battery specs not disclosed on the listing.'
from manufacturers where slug = 'sun-concept'
on conflict (slug) do nothing;

-- Silennis S010
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m, description
)
select id, 'S010', 'silennis-s010', 'tender', 'electric',
    3.95, 1.85,
    'Compact electric tender, price on request. Draft 0.5m. Motor/battery specs not disclosed on the listing.'
from manufacturers where slug = 'silennis'
on conflict (slug) do nothing;

-- Vision Marine Volt 180
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m, battery_kwh, top_speed_knots,
    price_from_eur, description
)
select id, 'Volt 180', 'vision-marine-volt-180', 'day_boat', 'electric',
    5.4, 2.13, 32, 26,
    33275,
    'Fibreglass-composite rotomolded electric day boat. Draft 0.3m. 32kWh lithium-ion battery pack manufactured by BMW, top speed up to 26 knots, motor rated around 180hp equivalent (per the model name/marketing) or listed elsewhere as an outboard rated up to 5hp — these figures conflict on the manufacturer''s own listing page, likely reflecting a mixed-up spec table (possibly combining data from more than one product variant). Treat both the motor power and detailed range figures as unconfirmed until checked directly with Vision Marine.'
from manufacturers where slug = 'vision-marine'
on conflict (slug) do nothing;

-- Vision Marine Volt X
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m, price_from_eur, description
)
select id, 'Volt X', 'vision-marine-volt-x', 'day_boat', 'electric',
    5.4, 2.13, 100000,
    'Higher-spec sibling to the Volt 180 on the same 5.4m hull — roughly 3x the starting price suggests a significantly more powerful motor/battery configuration, not confirmed in this research pass. Draft 0.3m.'
from manufacturers where slug = 'vision-marine'
on conflict (slug) do nothing;

-- Vision Marine Fantail 217
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m, price_from_eur, description
)
select id, 'Fantail 217', 'vision-marine-fantail-217', 'day_boat', 'electric',
    6.6, 2.03, 29500,
    'Entry-level rotomolded electric day boat in the Vision Marine range, part of the 6hp "classic electric boats" line mentioned on Vision''s own site. Draft 0.43m.'
from manufacturers where slug = 'vision-marine'
on conflict (slug) do nothing;

-- Marian M 800 Spyder — bowrider variant of the M800
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m, passenger_capacity, price_from_eur, description
)
select id, 'M 800 Spyder', 'marian-m800-spyder', 'day_boat', 'electric',
    7.9, 2.5, 10, 194000,
    'Bowrider-style variant of the M 800 on the same 7.9m hull, seating up to 10 (vs. 8 on the standard M 800). Draft 0.65m. Base price is higher than the M 800''s listed base (€184,600), likely reflecting a different standard motor/battery configuration — Marian builds to order across a 10-150kW motor range.'
from manufacturers where slug = 'marian-boats'
on conflict (slug) do nothing;

-- Marian Laguna 760 — top-of-range electro-yacht
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, motor_power_kw, top_speed_knots, description
)
select id, 'Laguna 760', 'marian-laguna-760', 'day_boat', 'electric',
    7.0, 125, 28.6,
    'Top-class model in Marian''s range per the manufacturer''s own site, blending traditional styling with a top speed of 53km/h (~28.6 knots) — similar performance tier to the Magic 640. 125kW electric motor, lithium-manganese battery chemistry (capacity not disclosed) — enough power to tow a water-skier. Built to order like the rest of the range.'
from manufacturers where slug = 'marian-boats'
on conflict (slug) do nothing;

-- Marian M 800-R — ABT Sportsline performance collaboration
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, description
)
select id, 'M 800-R', 'marian-m800-r', 'sport', 'electric',
    7.9,
    'High-performance collaboration between Marian and German automotive tuner ABT Sportsline, built on the M 800 hull. Positioned by the manufacturer as setting new standards for luxury electric sports boats. Detailed motor/battery specs not disclosed on the listing.'
from manufacturers where slug = 'marian-boats'
on conflict (slug) do nothing;

-- Marian Evo 700 — dedicated wakesurf model
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, description
)
select id, 'Evo 700', 'marian-evo-700', 'sport', 'electric',
    7.0,
    'Dedicated electric wakesurf boat, described by the manufacturer as more than a wakesurf boat — "the electric evolution" of the category. Detailed motor/battery specs not disclosed on the listing.'
from manufacturers where slug = 'marian-boats'
on conflict (slug) do nothing;

-- Marian Capriole 700
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m, motor_power_kw, battery_kwh, top_speed_knots,
    price_from_eur, description
)
select id, 'Capriole 700', 'marian-capriole-700', 'day_boat', 'electric',
    7.0, 2.45, 10, 21, 7,
    55000,
    'Draft 0.55m. Low-power/low-speed configuration: 10kW motor, 21kWh battery, top speed ~13km/h (~7 knots) — similar performance tier to the Delta 600 rather than the higher-powered Magic 640. Note: Marian''s own marketing mentions a new production facility in Romania alongside its established Austrian base, so this manufacturer may not be purely Austrian going forward.'
from manufacturers where slug = 'marian-boats'
on conflict (slug) do nothing;

-- Marian Magic 640
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m, motor_power_kw, battery_kwh, top_speed_knots,
    price_from_eur, description
)
select id, 'Magic 640', 'marian-magic-640', 'day_boat', 'electric',
    6.4, 2.2, 100, 84, 28.6,
    51600,
    'Draft 0.5m. 100kW motor, 84kWh battery (AGM or lithium option), top speed ~53km/h (~28.6 knots) — a notably higher-performance configuration than the Delta 600 despite similar dimensions.'
from manufacturers where slug = 'marian-boats'
on conflict (slug) do nothing;

-- Marian Delta 600
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m, motor_power_kw, battery_kwh, top_speed_knots,
    price_from_eur, description
)
select id, 'Delta 600', 'marian-delta-600', 'day_boat', 'electric',
    6.35, 2.15, 8, 21, 7,
    41000,
    'Draft 0.5m. Low-power/low-speed configuration: 8kW motor, 21kWh battery (AGM or lithium option), top speed ~13km/h (~7 knots) — positioned as a leisurely, displacement-speed model rather than a performance boat, unlike the similarly-sized Magic 640.'
from manufacturers where slug = 'marian-boats'
on conflict (slug) do nothing;

-- Marian Eclipse 580
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m, price_from_eur, description
)
select id, 'Eclipse 580', 'marian-eclipse-580', 'day_boat', 'electric',
    5.8, 1.8, 38700,
    'Smallest/entry model in the Marian range as listed on Volta Yachts. Draft 0.5m.'
from manufacturers where slug = 'marian-boats'
on conflict (slug) do nothing;

-- Helios Marine Helios Omega 7.2
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m, price_from_eur, description
)
select id, 'Omega 7.2', 'helios-marine-omega-7-2', 'day_boat', 'electric',
    7.2, 2.4, 67650,
    'Larger model in the Helios Marine range. Draft 0.5m. Motor/battery specs not disclosed on the listing.'
from manufacturers where slug = 'helios-marine'
on conflict (slug) do nothing;

-- Helios Marine Helios Sigma 4.5
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m, price_from_eur, description
)
select id, 'Sigma 4.5', 'helios-marine-sigma-4-5', 'tender', 'electric',
    4.5, 1.6, 15000,
    'Smallest, most affordable model in the Helios Marine range. Draft 0.2m. Motor/battery specs not disclosed on the listing.'
from manufacturers where slug = 'helios-marine'
on conflict (slug) do nothing;

-- Earthling E-40 Power Catamaran
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m, motor_power_kw,
    price_from_eur, description
)
select id, 'E-40 Power Catamaran', 'earthling-e40-power-catamaran', 'catamaran', 'electric',
    12.0, 5.5, 100,
    495000,
    'Draft 0.75m. Twin 50kW electric drives (100kW combined), ~3.5-3.6 tonnes, cruising at 10-12 knots. 2kW solar array (also used for water heating). Compact DC generators available as a hybrid range-extending backup. Completed a long-range delivery voyage from New Zealand to Barcelona under electric/hybrid power.'
from manufacturers where slug = 'earthling'
on conflict (slug) do nothing;

-- Soel Senses 62 — large solar-electric catamaran
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m, price_from_eur, description
)
select id, 'Senses 62', 'soel-senses-62', 'catamaran', 'electric',
    18.8, 10.3, 3490000,
    'Large solar-electric catamaran in the Soel Yachts range. Motor/battery specs not disclosed on the Volta listing.'
from manufacturers where slug = 'soel-yachts'
on conflict (slug) do nothing;

-- Soel Senses 82 — flagship solar-electric catamaran
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m, price_from_eur, description
)
select id, 'Senses 82', 'soel-senses-82', 'catamaran', 'electric',
    25.0, 13.0, 7195000,
    'Flagship of the Soel Yachts range. Motor/battery specs not disclosed on the Volta listing.'
from manufacturers where slug = 'soel-yachts'
on conflict (slug) do nothing;

-- SoelCat 12 — mid-size solar-electric catamaran
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m, passenger_capacity, price_from_eur, description
)
select id, 'SoelCat 12', 'soel-soelcat-12', 'catamaran', 'electric',
    14.5, 5.7, 20, 560000,
    'Draft 0.7m. Fully energy-autonomous (solar) catamaran, up to 20 passenger capacity. Available in a private-yacht configuration or a commercial-carrier configuration with passenger benches and a day head. Shippable worldwide disassembled into two 40ft containers. Motor/battery specs not disclosed on the listing.'
from manufacturers where slug = 'soel-yachts'
on conflict (slug) do nothing;

-- Soel Shuttle 14 — commercial passenger shuttle catamaran
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m, price_from_eur, description
)
select id, 'Shuttle 14', 'soel-shuttle-14', 'catamaran', 'electric',
    14.5, 5.1, 989000,
    'Commercial passenger-shuttle variant of Soel Yachts'' catamaran platform, aimed at ferry/water-taxi operators rather than private ownership. Motor/battery specs not disclosed on the Volta listing.'
from manufacturers where slug = 'soel-yachts'
on conflict (slug) do nothing;

-- La Bella Verde LBV 35
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m, price_from_eur, description
)
select id, 'LBV 35', 'la-bella-verde-lbv-35', 'catamaran', 'electric',
    11.7, 5.65, 287000,
    'Catamaran listed on the Volta Yachts marketplace. Draft 0.93m. Motor/battery specs not disclosed on the listing.'
from manufacturers where slug = 'la-bella-verde'
on conflict (slug) do nothing;

-- Zen Yachts ZenRiver — river-tourism electric houseboat
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    passenger_capacity, description
)
select id, 'ZenRiver', 'zen-yachts-zenriver', 'other', 'electric',
    12,
    'Low-speed electric boat designed for river/lake tourism rather than performance — 2 cabins, 6 berths, ~25 sqm of living space. Motor/battery specs and dimensions not confirmed in this research pass.'
from manufacturers where slug = 'zen-yachts'
on conflict (slug) do nothing;

-- LUMEN E10 — Dutch fast-displacement-hull electric yacht
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m, top_speed_knots, range_nm,
    description
)
select id, 'E10', 'lumen-e10', 'day_boat', 'electric',
    10.0, 3.0, 18.9,
    86,
    'Fast-displacement hull (combining full and semi-displacement characteristics) by Jaap de Jonge, exterior/interior design by Mulder Design, built by JR Yachts in Drachten, Netherlands. ~2,800kg. Range 100-160km (~54-86nm) at 10-13km/h (~5.4-7kn) cruise; max speed 30-35km/h (~16-19kn). Trailerable for use across different countries/lakes. Motor/battery brand and capacity not disclosed on the manufacturer''s public spec page.'
from manufacturers where slug = 'lumen-yachts'
on conflict (slug) do nothing;

-- Sun Concept CAT 12.0 Cruise — DISCONTINUED catamaran (also listed pre-owned)
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, beam_m, passenger_capacity, top_speed_knots,
    price_from_eur, status, description
)
select id, 'CAT 12.0 Cruise', 'sun-concept-cat-12-0-cruise', 'catamaran', 'electric',
    11.9, 6.0, 7, 15,
    676500, 'discontinued',
    'No longer in production per the Volta Yachts marketplace listing (which also lists a 2018 pre-owned unit from ~€342,000). Distinct from Sun Concept''s current EVO 7.0 day-cruiser line. Sleeping capacity for up to 7 across double cabins with private bathrooms; unlimited range at low speed. Battery capacity reported elsewhere (Volta''s own social media) at 140kWh+ with a 6kW solar array, though this figure was not confirmed on the primary listing page.'
from manufacturers where slug = 'sun-concept'
on conflict (slug) do nothing;

-- Sun Concept CAT 12.0 Lounge — DISCONTINUED catamaran variant
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m, passenger_capacity,
    price_from_eur, status, description
)
select id, 'CAT 12.0 Lounge', 'sun-concept-cat-12-0-lounge', 'catamaran', 'electric',
    12.0, 40,
    594000, 'discontinued',
    'Lounge-layout, commercial-oriented sibling to the CAT 12.0 Cruise, also no longer in production per the Volta Yachts marketplace listing. Rated for up to 40 passengers in commercial configuration, 27.5 sqm deck area. Motor/battery specs not independently confirmed.'
from manufacturers where slug = 'sun-concept'
on conflict (slug) do nothing;
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m,
    motor_power_kw, battery_kwh, top_speed_knots, range_nm,
    description
)
select id, '28 Speed', 'silent-yachts-28-speed', 'sport', 'electric',
    8.6,
    200, 100, 60, 70,
    'High-performance sibling to Silent Yachts'' cruising catamarans — a foil-assisted monohull-style speedboat with surface-piercing propellers, a notable departure from the rest of the Silent range. Twin 100kW eD-QDrive motors, 100kWh battery topped up by built-in solar. Grabbed attention at the 2022 Cannes Yachting Festival with a claimed 60+ knot top speed. Price not disclosed as of the 2023 source.'
from manufacturers where slug = 'silent-yachts'
on conflict (slug) do nothing;

-- X-Shore 1 — smaller, cheaper sibling to the Eelex 8000 (existing manufacturer)
insert into models (
    manufacturer_id, name, slug, category, propulsion_type,
    length_m,
    motor_power_kw, battery_kwh, top_speed_knots, range_nm,
    price_from_eur, description
)
select id, 'X Shore 1', 'x-shore-1', 'day_boat', 'electric',
    6.5,
    125, 63, 30, 50,
    129000,
    'Smaller, more affordable sibling to the Eelex 8000 on the same platform — same 30-knot top speed and similar range (50nm at 6 knots vs. the Eelex''s 100nm) despite roughly half the motor power and battery capacity (single 63kWh Kreisel pack vs. the Eelex''s two). Available as an open boat or semi-enclosed Top version. X Shore has also begun a commercial "Pro" variant on the Eelex platform for Swedish school-transport use. PRICE UPDATE: originally marketed at under €100,000 ex tax (2023 source); the Volta Yachts marketplace lists a current starting price of €129,000 as of this research pass — reflects a real price increase over time, not a data error.'
from manufacturers where slug = 'x-shore'
on conflict (slug) do nothing;

-- =====================================================================
-- SEED DATA — Model Powertrains (per-model, queryable engine detail)
-- =====================================================================

insert into model_powertrains (model_id, propulsion_type, is_primary, motor_brand, motor_model, motor_count, motor_power_kw, battery_brand, battery_kwh, charging_time_hours, fast_charge_minutes, top_speed_knots, cruise_speed_knots, range_nm, range_at_knots, price_from_eur, notes)
values
    ((select id from models where slug = 'candela-c-8'), 'electric', true,
     'Candela', 'C-Pod', 1, 75, 'Polestar', 69, 5, 45, 30, 22, 57, 22, 330000,
     'DC fast charge 10-80% in ~45 min; standard 3-phase dock charge ~5 hours.'),

    ((select id from models where slug = 'x-shore-eelex-8000'), 'electric', true,
     'Brusa', null, 1, 170, 'Kreisel', 126, 7, 60, 30, 22.5, 100, 6, 249000,
     'Standard charge 5-8 hours at 230V; DC fast charge 20-80% in ~1 hour.'),

    ((select id from models where slug = 'frauscher-850-fantom-air-porsche'), 'electric', true,
     'Porsche', 'Permanently excited synchronous motor', 1, 400, null, 100, null, null, null, null, null, null, 562000,
     'Joint Frauscher x Porsche powertrain, distinct from Frauscher''s Torqeedo-based electric options on other models.'),

    ((select id from models where slug = 'silent-yachts-60'), 'electric', true,
     'Dana TM4', null, 2, 400, null, 225, null, null, null, null, null, null, 2750000,
     'Twin ~200kW motors; diesel genset available as a range-extender, not a conventional propulsion option.'),

    ((select id from models where slug = 'silent-yachts-80-tri-deck'), 'electric', true,
     'Krautler', 'Solar', 2, 680, null, 429, null, null, 18, null, null, null, 5510000,
     'Twin 340kW motors (680kW combined); figure corrected from single-motor value used on the models summary row.'),

    ((select id from models where slug = 'sunreef-80-power-eco'), 'electric', true,
     null, null, 2, 360, null, null, null, null, null, null, null, null, null,
     'Twin 180kW motors per standard config (360kW combined); battery capacity is bespoke per build — the "Sol" custom unit reported ~990kWh with 360kW motors per hull (720kW combined). Do not assume a fixed battery figure for pricing/comparison.'),

    ((select id from models where slug = 'crooze-yachts-ez28'), 'electric', true,
     null, null, 1, 207, null, null, null, null, null, null, 120, 5, 258000,
     'Optional upgrade to 270kW motor available. Battery capacity not disclosed in public specifications as of last check.'),

    ((select id from models where slug = 'axopar-ax-e-25'), 'electric', true,
     'Evoy', 'Storm', 1, 225, null, 126, null, null, 50, null, 60, null, 229000,
     'Nominal 225kW / peak 450kW. Available in Cross Bow and Cross Top variants; Cross Top starts slightly higher at €234,000.'),

    ((select id from models where slug = 'marian-m800'), 'electric', true,
     null, null, 1, 150, null, 125, null, null, 34, 16, 30, 16, 238560,
     'Built-to-order: motor scales from 10-150kW and battery from 10kWh (AGM, lake use) to 125kWh (lithium, top spec) — figures shown here are the top-spec configuration.'),

    ((select id from models where slug = 'arc-boats-arc-one'), 'electric', true,
     'Arc', null, 1, 373, null, 220, null, 40, 35, null, 160, 35, 300000,
     'In-house Arc-designed motor and battery pack. Price shown in original USD ($300,000); EUR estimate elsewhere in this dataset uses an approximate conversion.'),

    ((select id from models where slug = 'arc-boats-arc-sport'), 'electric', true,
     'Arc', null, 1, 410, null, 225.5, null, null, 35, null, null, null, 240000,
     'In-house Arc-designed motor/battery. Motor rated 500-570hp (~373-425kW) depending on source; battery 225-226kWh. Wave-shaping ballast/tab system for wakeboarding and surfing.'),

    ((select id from models where slug = 'alva-ocean-eco-60'), 'electric', true,
     null, null, 1, null, null, null, null, null, 20, null, null, null, 2800000,
     'Motor/battery specs not disclosed in sources checked; solar array up to 20kW peak across ~80 sqm of panels, with hybrid generator backup for extended range.'),

    ((select id from models where slug = 'alfastreet-28-cabin-electric'), 'electric', true,
     null, null, 2, 20, null, 50, null, null, 7.5, 5, 50, 5, 175000,
     'Same hull also sold with petrol outboard/sterndrive power — see manufacturer product_line for the conventional option.'),

    ((select id from models where slug = 'boesch-750-portofino-deluxe-electric'), 'electric', true,
     'Piktronik', null, 2, 100, null, 71.2, 6, null, 21, null, 14, 20, 336000,
     'Traditional mahogany laminate hull; only Boesch models up to 25ft are offered with this electric powertrain.'),

    ((select id from models where slug = 'delphia-10-electric'), 'electric', true,
     null, null, 1, 60, null, null, null, null, null, null, null, null, null,
     'Electric shaft drive rated 40-80hp (~30-60kW); offered as an alternative to a diesel engine up to 110hp on the identical Vripack-designed hull.'),

    ((select id from models where slug = 'four-winns-h2e'), 'electric', true,
     'Vision Marine', null, 1, 134, null, null, null, null, 35, null, null, null, null,
     'Twin 700V batteries fitted; capacity not disclosed as of last update.'),

    ((select id from models where slug = 'hinckley-dasher'), 'electric', true,
     'Torqeedo', 'Deep Blue', 2, 60, 'BMW i3-derived li-ion', 80, 4, null, 23.5, 8.7, 40, 8.7, 500000,
     'RESOLVED (previously flagged as a conflict): twin 80hp Torqeedo Deep Blue motors and TWO 40kWh battery packs (80kWh combined) is now the primary spec, supported by 2 of 3 sources (2018 boats.com/YachtWorld launch review; 2025 EV Magazine feature). A single MBY (2023) source instead reported 2x50kW motors and a single 40kWh pack — kept here only as a minority-source footnote, not the primary figure. Charges 0-100% in 4 hours via dual 50A shore connections.'),

    ((select id from models where slug = 'nimbus-305-coupe-e-power'), 'electric', true,
     'Torqeedo', 'Deep Blue 50i', 1, 50, 'BMW i3', 42.2, 16, null, null, 5.7, 53, 5.7, 265000,
     'Official Nimbus spec. Optional dual-pack upgrade: 2x42.2kWh (84.4kWh total), fast-charging capable. Charge time 16hrs at 230V or 8hrs at 380V. At 3.7kn cruise, range extends to 86nm.'),

    ((select id from models where slug = 'nimbus-305-drophead-e-power'), 'electric', true,
     'Torqeedo', 'Deep Blue 50i', 1, 50, 'BMW i3', 42.2, 16, null, null, 5.7, 53, 5.7, 255000,
     'Shares the identical electric powertrain and optional dual-pack upgrade as the 305 Coupe E-Power.'),

    ((select id from models where slug = 'rand-source-22-electric'), 'electric', true,
     null, null, 1, 170, null, null, null, null, 50, 28, null, null, 100000,
     'Electric inboard option alongside petrol/diesel inboard or outboard engines up to 250hp on the same hull. A lower-power Torqeedo Deep Blue 50 outboard variant also exists at under €100,000 — confirm exact configuration before quoting a price.'),

    ((select id from models where slug = 'riva-el-iseo'), 'electric', true,
     'Parker', 'GVM310', 1, 300, null, 150, null, null, 40, 25, null, 25, null,
     'Now in production form, not just a prototype. Motor rated 250-300kW depending on source. Up to 10 hours of cruising in economy mode; three drive modes (Allegro/Andante/Adagio). Length discrepancy in one source flagged at the model level — see the models table description.'),

    ((select id from models where slug = 'nautique-gs22e'), 'electric', true,
     null, null, 1, 220, null, 124, null, null, 37.5, null, null, null, 288000,
     'Roughly a $140,000 premium over the petrol-powered Super Air Nautique GS22 it is based on.'),

    ((select id from models where slug = 'zodiac-450-e-jet'), 'electric', true,
     'Torqeedo', 'Deep Blue', 1, 50, 'BMW i3-derived', 40, null, null, 30, 24, 36, 24, 140800,
     'Drives a water jet rather than a propeller; targeted mainly at the superyacht tender market.'),

    ((select id from models where slug = 'frauscher-740-mirage-electric'), 'electric', true,
     'Torqeedo', null, 1, 110, null, 80, null, null, 26, null, 60, 5, 216616,
     'Lower-spec option also available: 60kW motor / 40kWh battery, giving a shorter ~17nm range at the 26-knot top speed.'),

    ((select id from models where slug = 'greenline-40-electric'), 'electric', true,
     null, null, 2, 100, null, 80, null, null, 11, 7, 30, 7, 445000,
     'Range extends to ~75nm at 5 knots with the optional 4kW range-extender generator. Same hull also offered as Hybrid (twin 220hp Volvo D3 diesels + electric-only cruising up to 20nm) or full diesel.'),

    ((select id from models where slug = 'sialia-45-sport'), 'electric', true,
     'AMPROS', null, 2, 300, null, 700, null, null, 43, 25, 164, 25, 800000,
     'Top-spec configuration shown. Three drivetrain tiers available: motors from 150-300kW per side, batteries from 300-700kWh. Pure-electric range without range extender is 70+nm; 164nm figure requires the optional range extender. DC fast charge up to 350kW.'),

    ((select id from models where slug = 'sialia-57-deep-silence'), 'electric', true,
     'AMPROS', null, 2, 800, null, null, null, null, 32, 18, 250, null, 4000000,
     'AC charging 22kW, DC fast charging 150kW. Diesel generator/backup extends single-charge range to a claimed 250nm and can recharge the battery 20-80% in about an hour. Battery capacity itself not independently published for this (2022-launched) model.'),

    ((select id from models where slug = 'sialia-80-explorer'), 'electric', true,
     'AMPROS', null, 2, 800, null, 800, null, null, 11, null, 3000, null, null,
     'Plus two variable-RPM range extenders for redundancy — this is a displacement-speed explorer optimized for range over top speed, unlike the rest of the Sialia range. Price not publicly disclosed (bespoke/quote-based).'),

    ((select id from models where slug = 'vita-power-tridente-maserati'), 'electric', true,
     'Vita Power', null, 1, 447, 'Vita Power', 252, null, 55, 40, 25, 50, 25, null,
     'DC supercharge 10-90% in under an hour. Motor rated at 600bhp by Maserati/Vita marketing, converted here to kW.'),

    ((select id from models where slug = 'vita-power-seal'), 'electric', true,
     'Vita Power', 'V150', 1, 95, 'Vita Power', 126, null, 55, 30, 20, null, null, 157000,
     'Continuous 95kW / peak 140kW. Available with single (63kWh) or dual (126kWh) battery — dual-pack figures shown here.'),

    ((select id from models where slug = 'vita-power-seadog'), 'electric', true,
     'Vita Power', 'V150', 1, 140, 'Vita Power', 63, null, 55, 30, null, null, null, 157000,
     'Single 63kWh battery pack; 140kW is the peak rating, continuous output is lower.'),

    ((select id from models where slug = 'vita-power-lion'), 'electric', true,
     'Vita Power', 'V4', 2, 300, 'Vita Power', 235, null, 55, 35, 22, 70, 22, 900000,
     'DATA CONFLICT — flagged for resolution before publishing: MBY (2023) lists twin 150kW motors (300kW combined, driving a single Mercury Bravo sterndrive), a 235kWh battery, top speed ~35 knots, cruise range 33-70nm at 22-7 knots, and a starting price of £750,000 ex VAT (~€900k converted). A separate, undated Robb Report source instead cites 590hp (~440kW) combined output and a $1.5m base price, with battery capacity undisclosed. The large price gap could reflect a genuine increase since 2023, a different trim level, or a reporting error — confirm current spec and pricing directly with Vita Power before publishing.'),

    ((select id from models where slug = 'tyde-the-icon'), 'electric', true,
     'Torqeedo', null, 2, 200, 'BMW i3-derived', 240, null, null, 30, 24, 50, 20, null,
     'Six BMW i3 battery modules (~530 lbs each) totalling 240kWh. Foils out of the water at 18 knots. Price not disclosed — positioned for B2B commercial buyers (resorts, luxury ferry operators) rather than retail sale.'),

    ((select id from models where slug = 'enata-marine-foiler'), 'hybrid_electric', true,
     null, null, 2, 448, null, null, null, null, 40, 30, 113, 30, 990000,
     'Diesel-electric series hybrid: twin 300hp (~224kW each, 448kW combined) diesel engines drive generators; twin electric motors in torpedo-shaped housings drive the props. Pure-electric-only mode: 10 minutes at 10 knots, for marina use. Do NOT classify this as pure electric on comparison pages despite the silent-running foiling marketing.'),

    ((select id from models where slug = 'flux-marine-scout-215-dorado'), 'electric', true,
     'Flux Marine', 'Flux 100', 1, 112, null, 84, null, null, 27.8, 21.7, 26, 21.7, null,
     'Hull built by Scout Boats (conventional builder); Flux supplies the electric outboard.'),

    ((select id from models where slug = 'flux-marine-highfield-sport-660'), 'electric', true,
     'Flux Marine', null, 1, 86, null, 84, null, null, 29.5, null, 22, null, null,
     'Hull built by Highfield (conventional RIB builder); Flux supplies the electric outboard, rated up to 150hp peak acceleration.'),

    ((select id from models where slug = 'magonis-wave-e550'), 'electric', true,
     null, null, 1, 22, null, 28.65, 9, 150, 22, null, 30, 5, 68900,
     'Top-spec 30kW Mag Power configuration shown; lower-cost Torqeedo 4kW/10kW options also available with smaller batteries and lower top speeds (5-9 knots) starting from €33,485.'),

    ((select id from models where slug = 'chris-craft-launch-25-gte'), 'electric', true,
     'EVOA', 'E1', 1, 313, null, 133, null, null, 43, null, null, null, null,
     'Concept/prototype only. 200Wh/kg battery energy density claimed; Level 2 charging is the fastest currently supported. ~2 hours runtime.'),

    ((select id from models where slug = 'elvene-amber'), 'electric', true,
     null, null, 2, 22, null, 22, null, null, 15, 9.5, 100, 5, 90000,
     'Range figure is for battery-only operation in darkness at 5 knots; in daylight the boat can run indefinitely at 5 knots with zero net battery draw thanks to solar.'),

    ((select id from models where slug = 'elvene-amy'), 'electric', true,
     'Molabo', 'ARIES', 1, 50, null, null, null, null, 30, 20, 35, 20, null,
     '48V "safe-to-touch" system from German propulsion partner Molabo.'),

    ((select id from models where slug = 'princecraft-brio-e17'), 'electric', true,
     'Torqeedo', null, 1, null, null, null, null, null, null, null, null, null, 13000,
     'Exact Torqeedo model has varied by model year (2.0R/4.0R through 3.0RL/6.0RL/12.0RL) — confirm current-year spec before publishing.'),

    ((select id from models where slug = 'volare-artemis-23'), 'electric', true,
     null, null, 2, 50, null, null, null, null, 26, null, 35, null, null,
     '48V direct-drive system, each 25kW motor pod rotates 90° for joystick maneuvering (Optimus 360 system).'),

    ((select id from models where slug = 'novaluxe-orphie-39'), 'electric', true,
     null, null, 1, null, null, null, null, null, null, null, null, null, null,
     'Motor and battery specs not independently confirmed in this research pass — solar-integrated trimaran, treat as incomplete pending direct manufacturer confirmation.'),

    ((select id from models where slug = 'vision-marine-v24'), 'electric', true,
     'Vision Marine', 'E-Motion 180E', 1, 134, null, 43, null, null, null, null, 40, null, 92000,
     'Optional second battery pack brings total to 86kWh and range to ~90nm — priced separately from the base $99,995.'),

    ((select id from models where slug = 'vision-marine-v30'), 'electric', true,
     'Vision Marine', 'E-Motion 180E', 1, 134, null, 43, null, null, null, null, 40, null, 129000,
     'Same dual battery-pack range options as V24 (43kWh/86kWh); optional pack priced separately from the base $139,995.'),

    ((select id from models where slug = 'vision-marine-phantom'), 'electric', true,
     null, null, 1, null, null, null, null, null, null, null, null, null, null,
     'Rotomolded plastic construction; motor/battery specs need direct confirmation from Vision Marine before publishing.'),

    ((select id from models where slug = 'cosmopolitan-yachts-66'), 'electric', true,
     null, null, 2, 360, null, 450, null, null, 20, null, null, null, null,
     'Uses batteries, solar panels, and ICE generators together; treated as electric with generator range-extension rather than a conventional propulsion mode. Range/price undisclosed as of 2023.'),

    ((select id from models where slug = 'duffy-sun-cruiser-22'), 'electric', true,
     null, null, 1, 50, null, null, null, null, 5.5, 5.5, 40, 5.5, 43000,
     '48V system, 16x six-volt batteries. Patented Power Rudder integrates motor/rudder/prop for docking ease.'),

    ((select id from models where slug = 'hermes-speedster-e'), 'electric', true,
     null, null, 1, 100, null, 30, null, null, 30, 5, 50, 5, 186000,
     'Combustion sibling uses a 115hp Rotax engine; this is the electric option added since ~2020. Range figure at 5kn displacement speed.'),

    ((select id from models where slug = 'mantaray-m24'), 'electric', true,
     null, null, 1, 48, null, 26, null, null, 30, null, 60, null, null,
     'Mechanical (not electronic) hydrofoil control system — Dynamic Wing Technology. Price undisclosed as of 2023.'),

    ((select id from models where slug = 'mayla-fortyfour'), 'electric', true,
     null, null, 2, 800, null, 500, null, null, 70, 30, 70, 30, null,
     'All-electric configuration shown (500kWh battery). Hybrid alternative: 400kWh battery + 400hp diesel generator, extending range to 270nm at 30kn.'),

    ((select id from models where slug = 'navier-n30'), 'electric', true,
     null, null, 2, 180, null, 80, null, null, 35, 20, 75, 20, 276000,
     'Retractable hydrofoils; self-docking feature on both Cabin and Hardtop versions.'),

    ((select id from models where slug = 'nero-777-evolution'), 'electric', true,
     'Evoy', null, 1, 300, null, 126, null, null, 50, 5, 108, 5, 265000,
     'Range figure (108nm) is at a 5-knot low-speed setting; top speed of 50+ knots only with the highest (300kW) of five available Evoy propulsion options.'),

    ((select id from models where slug = 'optima-e10'), 'electric', true,
     'Rad Propulsion', null, 1, 40, 'Kreisel', 120, null, null, 15, 6, 200, 6, 467000,
     'Stabilised monohull with outrigger side-hulls; long range (200nm) achieved at just 6 knots displacement speed.'),

    ((select id from models where slug = 'pixii-sp800'), 'electric', true,
     null, null, 2, 50, null, 150, null, null, 40, 14, 100, 14, 133000,
     'Jet-drive propulsion (1 or 2 motors); still in development on the Isle of Wight as of the 2023 source.'),

    ((select id from models where slug = 'persico-zagato-100-2'), 'electric', true,
     'Sealence', 'DeepSpeed 420', 1, 205, null, 166, null, null, 43.5, 24, 47, 24, null,
     'Steerable electric waterjet azipod rather than a conventional prop/sterndrive. Price undisclosed as of 2023.'),

    ((select id from models where slug = 'q-yachts-q30'), 'electric', true,
     null, 'POD drive', 2, 24, null, 30, null, null, 14, 6, 54, 6, 183000,
     'Separate battery per motor for redundancy. Silent cruise 6kn/54nm; mid cruise 9kn/42nm; max 14kn usable ~1.5hrs (22nm).'),

    ((select id from models where slug = 'ripple-boats-10m-day-cruiser'), 'electric', true,
     null, null, 2, 186, null, 190, null, null, null, 25, 45, 25, null,
     'Debut model; price undisclosed as of 2023.'),

    ((select id from models where slug = 'rs-sailing-pulse-63'), 'electric', true,
     'RAD Propulsion', null, 1, 40, 'Hyperdrive', 46, null, null, 23, null, 100, 5, 97000,
     'Optional extra 23kWh battery pack extends range further. First British production-ready electric planing RIB.'),

    ((select id from models where slug = 'say-carbon-29e'), 'electric', true,
     'Kreisel', null, 1, 360, null, 120, 6, null, 52, 22, 25, 22, 396460,
     'Under 2 tonnes all-up; held the fastest-production-electric-boat-under-9m record as of 2018. Built-in 22kW charger.'),

    ((select id from models where slug = 'spirit-yachts-bartech-35ef'), 'electric', true,
     null, null, 1, null, null, null, null, null, 28, 20, 100, 20, null,
     'One-off commission; motor/battery details and pricing not disclosed (available on application only).'),

    ((select id from models where slug = 'voltari-260'), 'electric', true,
     null, null, 1, 551, null, 142, null, null, 52, null, 79, 4.3, 415000,
     'Set a record for longest single-charge distance by an electric boat (~79nm at ~4.3kn average, Florida to Bahamas).'),

    ((select id from models where slug = 'silent-yachts-28-speed'), 'electric', true,
     'eD-QDrive', null, 2, 200, null, 100, null, null, 60, 30, 70, 30, null,
     'Foil-assisted hull with surface-piercing propellers — a notable performance departure from the rest of the Silent Yachts range. Price undisclosed as of 2023.'),

    ((select id from models where slug = 'x-shore-1'), 'electric', true,
     null, null, 1, 125, 'Kreisel', 63, null, null, 30, 20, 50, 6, 100000,
     'Half the motor power and one battery pack (vs. two on the Eelex 8000) but matches its 30-knot top speed thanks to a lighter hull.'),

    ((select id from models where slug = 'blue-innovations-group-r30'), 'electric', true,
     null, null, 2, 298, null, 221, null, 45, 39, null, null, null, 280000,
     'Twin 298kW motors, 596kW/800hp combined. DC fast-charge to 80% in 45 minutes.');

-- =====================================================================
-- SEED DATA — Initial English content_pages (primary domain template)
-- =====================================================================
-- Small starter set: one pillar/overview page, one buyer's guide, and one
-- featured-partner page for Crooze Yachts (the only manufacturer with a
-- live commission agreement as of this writing). Rendered at /guides/[slug].

insert into content_page_groups (group_key, content_type, country, related_manufacturer_id, related_model_id)
values
    ('electric-yachts-europe-overview', 'landing_page', null, null, null),
    ('electric-yacht-buyers-guide', 'buyer_guide', null, null, null),
    ('crooze-yachts-ez28-feature', 'model_page', null,
        (select id from manufacturers where slug = 'crooze-yachts'),
        (select id from models where slug = 'crooze-yachts-ez28'))
on conflict (group_key) do nothing;

insert into content_pages (page_group_id, title, slug, url_path, language, primary_keyword, meta_description, body_markdown, status, published_at)
values
    ((select id from content_page_groups where group_key = 'electric-yachts-europe-overview'),
     'Electric Yachts in Europe: The Complete Overview',
     'electric-yachts-europe-overview',
     '/guides/electric-yachts-europe-overview',
     'en',
     'electric yachts',
     'A guide to the electric and hybrid-electric yacht market in Europe — what''s available, how the boats compare, and what to consider before buying.',
$md$## What is an electric yacht?

An electric yacht replaces the diesel or petrol engine found on a conventional boat with an electric motor powered by an onboard battery pack, charged from shore power like an electric car. A smaller number of "hybrid-electric" models pair a combustion engine or generator with an electric drivetrain, offering silent, zero-emission running at low speed with a combustion range-extender for longer trips.

## Why interest is growing

A mix of factors is pushing electric propulsion onto the water: tightening emissions rules in some European harbours and lakes, a growing number of electric-only marinas and no-wake zones, and the simple appeal of a boat that runs near-silently with no exhaust fumes. Charging infrastructure at marinas is still catching up to demand, which is one of the biggest practical considerations for a first-time buyer — see our [buyer's guide](/guides/electric-yacht-buyers-guide).

## Who's building them

The market splits into two groups. **Electric-only builders** — companies like Candela, ARC Boats, X Shore, and Vita Power — were founded specifically around electric propulsion and design their hulls, hydrofoils, and battery systems around it from the start. **Mixed manufacturers** — established combustion-boat builders such as Frauscher, Sunreef, Riva, and Axopar — have added one or more electric models to an otherwise conventional range, often as a flagship or halo model rather than their volume product.

## What's available

Electric yachts on the market today span day boats and tenders (the largest category, generally under 10m), sport boats and RIBs built for performance, larger cruisers and catamarans with liveaboard accommodation, and a small number of ultra-luxury flagship models. Prices range from roughly €90,000 for an entry-level day boat to several million euros for the largest catamarans and cruisers.

## Range and charging, realistically

Electric range is the single biggest difference from a combustion boat, and it varies enormously with speed: most electric yachts get dramatically more range at a gentle cruising speed (often 5-8 knots) than at top speed, sometimes by a factor of 3-4x. When comparing models, look at the range figure's stated speed, not just the headline number.

## Explore the data

This site tracks the manufacturers and models in this market with verified specifications. Browse [all manufacturers](/manufacturers), [all models](/models), or use the [comparison tool](/compare) to put two or more boats side by side.
$md$,
     'published', now()),

    ((select id from content_page_groups where group_key = 'electric-yacht-buyers-guide'),
     'How to Buy an Electric Yacht: A Buyer''s Guide',
     'electric-yacht-buyers-guide',
     '/guides/electric-yacht-buyers-guide',
     'en',
     'how to buy an electric yacht',
     'What actually matters when buying an electric yacht — range and battery, charging, motor power, hull type, and how to verify a manufacturer''s claims.',
$md$## Start with how you'll actually use the boat

Range, motor power, and passenger capacity all depend on the answer to one question: what are you actually going to do with the boat? A boat used for short trips around a marina or lake has very different requirements from one intended for longer coastal cruising. Day boats and tenders suit the former; cruisers and catamarans the latter.

## Range and battery capacity

Battery capacity (measured in kWh) is only half the story — the other half is speed. Nearly every electric yacht's real-world range is quoted at a specific cruising speed, and that range drops sharply as you go faster. A boat advertised with "50nm range" might mean 50nm at a gentle 6 knots, and far less at its 25-knot top speed. Always check the speed a range figure is quoted at, and if a manufacturer doesn't state one, ask.

## Charging

Most electric yachts charge from standard shore power (AC), typically taking anywhere from a few hours to overnight for a full charge, depending on battery size and the charger's power rating. A smaller number of models support DC fast charging, which can bring a battery from low to mostly full in under an hour — useful if you're planning multiple outings in a day. Marina charging infrastructure varies a lot by country and even by marina, so it's worth confirming what's actually available where you plan to keep the boat before assuming a fast-charge model will let you charge quickly in practice.

## Motor power and performance

Motor power (kW) determines top speed and acceleration, not range — a more powerful motor drains the battery faster at a given speed, but doesn't by itself extend how far you can go. Some models are sold with a choice of motor and battery configurations on the same hull; if that's the case, make sure the spec sheet you're comparing is for the exact configuration you're pricing.

## Hull type and category

Day boats and tenders are the most common and affordable electric category, typically under 10m with modest range needs. Sport boats and hydrofoiling designs trade some passenger space for speed and efficiency. Cruisers and catamarans offer overnight accommodation but come with a much higher price tag and, in most cases, shorter relative range than their combustion equivalents of the same size.

## CE category and regulatory notes

European recreational boats carry a CE category (A, B, C, or D) reflecting the sea conditions they're certified for. This is independent of propulsion type, but worth confirming for any boat you're considering, especially if you plan to use it somewhere with open-water conditions.

## Verifying manufacturer claims

Specifications published by different sources (a manufacturer's own site, boat show coverage, marine press) don't always agree, particularly on battery capacity, motor power, and price. It's normal — and worth doing — to confirm the current-year spec and price directly with the manufacturer or a dealer before making a decision, since the numbers on any single web page (including this one) can be out of date.

## Compare before you decide

Once you've narrowed down a use case and budget, the fastest way to see how boats stack up is side by side. Use the [comparison tool](/compare) to compare specs across [any two or more models](/models) in the database.
$md$,
     'published', now()),

    ((select id from content_page_groups where group_key = 'crooze-yachts-ez28-feature'),
     'Crooze Yachts EZ28: Featured Electric Day Boat',
     'crooze-yachts-ez28-feature',
     '/guides/crooze-yachts-ez28-feature',
     'en',
     'Crooze Yachts EZ28',
     'A closer look at the Crooze Yachts EZ28, an all-electric day boat built around six customizable use scenarios, from Bulgarian manufacturer Crooze Yachts.',
$md$> **Featured partner:** Crooze Yachts is a commission partner of this site. That doesn't change what's reported below — every specification here comes from Crooze Yachts' own published data, the same as any other model in our database.

## A day boat built around how you'll actually use it

The EZ28 is Crooze Yachts' flagship all-electric day boat, designed around six distinct use scenarios that reconfigure the same 8.67m hull: Commuting, Fishing, Water sports, Party, Picnic, and Beach. Rather than a single fixed layout, the boat is built to be reconfigured for whichever of those the owner needs on a given day.

## Power and range

The EZ28 ships with a 207kW motor as standard, with an optional upgrade to 270kW for owners who want more performance. Crooze Yachts quotes a range of roughly 120 nautical miles at a 5-knot cruising speed — as with any electric boat, expect meaningfully less range at higher speeds. Battery capacity has not been disclosed in Crooze Yachts' public specifications as of our last check; we'll update this page once that's confirmed.

## Comfort and layout

At 8.67m with capacity for 12 passengers, the EZ28 is fitted with a WC, wet bar and grill, a stern shower, an enlarged beach area, and folding top-sides that open up 17 square metres of usable floor space — features aimed squarely at day-long use rather than short outings.

## Where it sits in the market

In its size class, the EZ28 competes with boats like the Frauscher x Porsche 850 Fantom Air, ARC Boats' range, Axopar's electric model, and Marian Boats — its combination of six reconfigurable use scenarios and beach-focused layout is its main point of difference from that group.

## Recognition

The EZ28 was a finalist at the 2025 Gussies Electric Boat Awards.

## See the full spec sheet

For the complete verified specification, see the [EZ28 model page](/models/crooze-yachts-ez28), or browse [all Crooze Yachts models](/manufacturers/crooze-yachts).
$md$,
     'published', now())
on conflict (page_group_id, language) do nothing;

-- =====================================================================
-- Notes
-- =====================================================================
-- 1. This covers only the 5 "start now" tables recommended in the strategy
--    discussion (Manufacturers, Models, Leads, Deals, Content/SEO — the
--    last one split into content_page_groups + content_pages for i18n).
-- 2. Remaining 7 tables (Domains/Local Markets, Comparisons, Partners,
--    Offers/Quotes, Payments/Commissions, Media Library, Analytics) can be
--    layered on later without breaking this schema — they mostly reference
--    manufacturers.id and models.id as foreign keys. Deferred per current
--    scope decision.
-- 3. commission_amount_eur is a generated column so it's always in sync
--    with sale_price_eur and commission_rate_pct — no app-side calculation
--    needed for reporting.
-- 4. All UUID PKs + citext slugs make this friendly for both Supabase
--    (RLS policies keyed on is_staff()) and Neon. On Neon (no built-in
--    auth.users), either skip the RLS section entirely, or swap
--    `references auth.users(id)` in staff_users for a plain uuid column
--    fed by your own auth provider.
-- 5. Multilingual content: create ONE content_page_groups row per concept
--    (e.g. "electric-yachts-germany-guide"), then one content_pages row
--    per language pointing at that group_id. Shared metadata (content_type,
--    target country, related manufacturer/model) lives on the group;
--    title/slug/body/SEO metrics live per-language row.
-- 6. Manufacturer data verified via manufacturer websites and marine press
--    (mid-2026). Sunreef Power Eco battery capacity is bespoke per build,
--    so battery_kwh is intentionally left null for that model — do not
--    guess a number for pricing/comparison pages.
-- 7. Engine/motor detail lives in model_powertrains, NOT bolted onto
--    `models`. Query it directly for anything engine-specific, e.g.:
--      -- all boats using a Torqeedo motor
--      select m.name, mf.name as manufacturer, p.motor_model, p.motor_power_kw
--      from model_powertrains p
--      join models m on m.id = p.model_id
--      join manufacturers mf on mf.id = m.manufacturer_id
--      where p.motor_brand = 'Torqeedo';
--    Models with multiple drivetrain choices (Delphia 10, Rand Source 22,
--    Alfastreet, Greenline) currently exist as separate `models` rows per
--    variant (e.g. "Delphia 10 (Electric)") rather than one model row with
--    multiple powertrain rows — a cleaner future refactor would be a
--    single canonical model row per hull with is_primary distinguishing
--    the default listed configuration in model_powertrains. Flagging this
--    as a known simplification, not a hidden inconsistency.

-- =====================================================================
-- SEED DATA — Market Tier Classification
-- =====================================================================
-- Classification basis: list price (price_from_eur where known), brand
-- positioning/heritage, and build materials/craftsmanship signals from
-- each model's description. This is an editorial judgment call, not a
-- hard formula — revisit as real pricing/market data comes in.
--
-- crooze-yachts-ez28 is deliberately marked 'luxury': this is the model
-- with a confirmed commission/sales agreement and full specification
-- access, and it is explicitly tagged "LUXURY: YES" on the user-supplied
-- competition-landscape slide used earlier in this dataset.

update models set market_tier = v.tier
from (values
    ('candela-c-8',                          'luxury'::market_tier),
    ('x-shore-eelex-8000',                   'premium'::market_tier),
    ('frauscher-850-fantom-air-porsche',     'ultra_luxury'::market_tier),
    ('silent-yachts-60',                     'ultra_luxury'::market_tier),
    ('silent-yachts-80-tri-deck',            'ultra_luxury'::market_tier),
    ('silent-yachts-62',                     'ultra_luxury'::market_tier),
    ('sunreef-80-power-eco',                 'ultra_luxury'::market_tier),
    ('crooze-yachts-ez28',                   'luxury'::market_tier),  -- mandatory: confirmed commission deal
    ('axopar-ax-e-25',                       'premium'::market_tier),
    ('marian-m800',                          'luxury'::market_tier),
    ('arc-boats-arc-one',                    'luxury'::market_tier),
    ('arc-boats-arc-sport',                   'luxury'::market_tier),
    ('alva-ocean-eco-60',                     'ultra_luxury'::market_tier),
    ('alfastreet-28-cabin-electric',         'entry'::market_tier),
    ('boesch-750-portofino-deluxe-electric', 'luxury'::market_tier),
    ('delphia-10-electric',                  'entry'::market_tier),
    ('four-winns-h2e',                       'entry'::market_tier),
    ('hinckley-dasher',                      'ultra_luxury'::market_tier),
    ('nimbus-305-coupe-e-power',             'entry'::market_tier),
    ('nimbus-305-drophead-e-power',          'entry'::market_tier),
    ('lumen-e10',                             'luxury'::market_tier),
    ('rand-source-22-electric',              'premium'::market_tier),
    ('rand-mana-23',                         'entry'::market_tier),
    ('rand-leisure-28-electric',              'premium'::market_tier),
    ('rand-escape-30',                        'premium'::market_tier),
    ('rand-spirit-25-electric',               'premium'::market_tier),
    ('candela-seven',                         'luxury'::market_tier),
    ('strana-23',                              'entry'::market_tier),
    ('pol-lux',                                'premium'::market_tier),
    ('riva-el-iseo',                         'ultra_luxury'::market_tier),
    ('nautique-gs22e',                       'premium'::market_tier),
    ('zodiac-450-e-jet',                     'premium'::market_tier),
    ('frauscher-740-mirage-electric',        'luxury'::market_tier),
    ('greenline-40-electric',                'luxury'::market_tier),
    ('sialia-45-sport',                      'ultra_luxury'::market_tier),
    ('sialia-57-deep-silence',               'ultra_luxury'::market_tier),
    ('sialia-59-sport',                      'ultra_luxury'::market_tier),
    ('sialia-80-explorer',                   'ultra_luxury'::market_tier),
    ('vita-power-tridente-maserati',         'ultra_luxury'::market_tier),
    ('vita-power-seal',                      'premium'::market_tier),
    ('vita-power-seadog',                    'premium'::market_tier),
    ('vita-power-lion',                      'ultra_luxury'::market_tier),
    ('tyde-the-icon',                        'ultra_luxury'::market_tier),
    ('enata-marine-foiler',                  'ultra_luxury'::market_tier),
    ('flux-marine-scout-215-dorado',         'entry'::market_tier),
    ('flux-marine-highfield-sport-660',      'entry'::market_tier),
    ('magonis-wave-e550',                    'entry'::market_tier),
    ('chris-craft-launch-25-gte',            'luxury'::market_tier),
    ('elvene-amber',                         'premium'::market_tier),
    ('elvene-amy',                           'premium'::market_tier),
    ('princecraft-brio-e17',                 'entry'::market_tier),
    ('volare-artemis-23',                    'premium'::market_tier),
    ('novaluxe-orphie-39',                   'premium'::market_tier),
    ('vision-marine-v24',                    'entry'::market_tier),
    ('vision-marine-v30',                    'entry'::market_tier),
    ('vision-marine-phantom',                'entry'::market_tier),
    ('alfastreet-23-cabin-evo',               'premium'::market_tier),
    ('crest-current-model',                   'entry'::market_tier),
    ('novaluxe-elight-40',                    'premium'::market_tier),
    ('pure-watercraft-pure-pontoon',          'entry'::market_tier),
    ('vision-marine-wx-20',                   'entry'::market_tier),
    ('vision-marine-wx-23',                   'entry'::market_tier),
    ('electracraft-tr-152',                   'entry'::market_tier),
    ('gosun-elcat',                           'entry'::market_tier),
    ('candela-p-12',                          'premium'::market_tier)
) as v(slug, tier)
where models.slug = v.slug;

-- Additional market_tier classification for models added from the MBY
-- "A-Z of electric boats" (2023) research pass.
update models set market_tier = v.tier
from (values
    ('cosmopolitan-yachts-66',            'ultra_luxury'::market_tier),
    ('duffy-sun-cruiser-22',              'entry'::market_tier),
    ('hermes-speedster-e',                'premium'::market_tier),
    ('mantaray-m24',                      'premium'::market_tier),
    ('mayla-fortyfour',                   'ultra_luxury'::market_tier),
    ('navier-n30',                        'premium'::market_tier),
    ('nero-777-evolution',                'luxury'::market_tier),
    ('optima-e10',                        'luxury'::market_tier),
    ('pixii-sp800',                       'premium'::market_tier),
    ('persico-zagato-100-2',              'ultra_luxury'::market_tier),
    ('q-yachts-q30',                      'premium'::market_tier),
    ('ripple-boats-10m-day-cruiser',      'premium'::market_tier),
    ('rs-sailing-pulse-63',               'premium'::market_tier),
    ('say-carbon-29e',                    'luxury'::market_tier),
    ('spirit-yachts-bartech-35ef',        'ultra_luxury'::market_tier),
    ('voltari-260',                       'luxury'::market_tier),
    ('silent-yachts-28-speed',            'ultra_luxury'::market_tier),
    ('x-shore-1',                         'premium'::market_tier),
    ('blue-innovations-group-r30',        'luxury'::market_tier),
    ('sun-concept-evo-7-0-cruise',        'entry'::market_tier),
    ('sun-concept-evo-7-0-lounge',        'entry'::market_tier),
    ('silennis-s010',                     'entry'::market_tier),
    ('vision-marine-volt-180',            'entry'::market_tier),
    ('vision-marine-volt-x',              'premium'::market_tier),
    ('vision-marine-fantail-217',         'entry'::market_tier),
    ('marian-m800-spyder',                'luxury'::market_tier),
    ('marian-capriole-700',               'premium'::market_tier),
    ('marian-magic-640',                  'premium'::market_tier),
    ('marian-delta-600',                  'entry'::market_tier),
    ('marian-eclipse-580',                'entry'::market_tier),
    ('helios-marine-omega-7-2',           'entry'::market_tier),
    ('helios-marine-sigma-4-5',           'entry'::market_tier),
    ('earthling-e40-power-catamaran',     'premium'::market_tier),
    ('soel-senses-62',                    'ultra_luxury'::market_tier),
    ('soel-senses-82',                    'ultra_luxury'::market_tier),
    ('soel-soelcat-12',                   'luxury'::market_tier),
    ('soel-shuttle-14',                   'luxury'::market_tier),
    ('la-bella-verde-lbv-35',             'premium'::market_tier),
    ('sun-concept-cat-12-0-cruise',       'luxury'::market_tier),
    ('sun-concept-cat-12-0-lounge',       'luxury'::market_tier),
    ('zen-yachts-zenriver',               'premium'::market_tier)
) as v(slug, tier)
where models.slug = v.slug;

-- =====================================================================
-- SEED DATA — Featured flag
-- =====================================================================
-- Crooze Yachts EZ28 is the only model with a live commission agreement
-- (see CLAUDE.md) — flagged featured so it surfaces on the homepage.

update models set is_featured = true where slug = 'crooze-yachts-ez28';

-- =====================================================================
-- SEED DATA — EZ28 imagery
-- =====================================================================
-- Official Crooze Yachts renders, stored in the Next.js app's
-- public/images/ez28/ folder (paths are app-relative, served by the
-- same deployment on every domain). color_variant_urls = the five hull
-- colour configurator renders; gallery_urls = curated lifestyle and
-- interior shots; hero = the black variant (the homepage cover photo,
-- and the configurator's lead image on the model page).

update models set
    hero_image_url = '/images/ez28/EZ_28_black.jpg',
    color_variant_urls = array[
        '/images/ez28/EZ_28_white.jpg',
        '/images/ez28/EZ_28_green.jpg',
        '/images/ez28/EZ_28_blue.jpg',
        '/images/ez28/EZ_28_gray.jpg',
        '/images/ez28/EZ_28_black.jpg'
    ],
    gallery_urls = array[
        -- atmosphere
        '/images/ez28/EZ28_14.jpg',      -- atmospheric wide on-water side view (lead image)
        '/images/ez28/EZ28_13.jpg',      -- white hull, misty morning bow 3/4
        '/images/ez28/EZ28_4.jpg',       -- silver hull, calm morning anchorage
        '/images/ez28/EZ28_5.jpg',       -- misty stern 3/4 with aft sunbed out
        -- hull colours on the water
        '/images/ez28/EZ28_2.jpg',       -- blue hull at anchor, 3/4 bow
        '/images/ez28/EZ28_15.jpg',      -- blue hull stern 3/4, overcast
        '/images/ez28/EZ28_17.jpg',      -- mint hull side profile
        '/images/ez28/EZ28_16.jpg',      -- mint hull with rod rack & sunshade
        -- deck configurations
        '/images/ez28/EZ_28_shades2.jpg',-- both sunshades extended, aerial 3/4
        '/images/ez28/EZ_28_table.jpg',  -- aft deck table & benches, sunset close-up
        '/images/ez28/EZ28_3.jpg',       -- aft sunbed configuration, aerial 3/4
        '/images/ez28/EZ28_12.jpg',      -- sunset stern, folding decks & furniture
        -- aerials
        '/images/ez28/EZ28_9.jpg',       -- top-down underway with wake
        '/images/ez28/EZ28_10.jpg',      -- top-down at anchor, deck layout
        -- details & interior
        '/images/ez28/EZ28_7.jpg',       -- bow seating & table, top view
        '/images/ez28/EZ28_11.jpg',      -- sunset aft view over the helm
        '/images/ez28/EZ28_6.jpg',       -- helm detail with navigation display
        '/images/ez28/EZ28_8.jpg',       -- cockpit seating interior
        '/images/ez28/EZ28-T.jpg',       -- head/WC: basin, towel & toilet
        '/images/ez28/EZ28-T1.jpg'       -- head/WC: top-down teak floor view
    ]
where slug = 'crooze-yachts-ez28';
