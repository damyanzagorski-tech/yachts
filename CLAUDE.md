# electroyachts.com — Project Context

## What this is
An SEO/content + affiliate/lead-generation site targeting the European electric
yacht market (buyers researching electric/hybrid yachts, manufacturers wanting
qualified leads). Business model: content-driven traffic → manufacturer
listings/featured placement → qualified lead packages → eventual commission
on sales (see "Monetization model" below). Long-term vision is a data
platform first, marketplace second — the structured database of
manufacturers/models is meant to be the durable asset, with the website as
one interface into it (others: AI buying assistant, dealer portal,
manufacturer analytics dashboard).

Owner/operator: Damyan. Also runs an SEO/domains business (SEO Domains) and
doublespark.co.uk — electroyachts.com is a separate, newer venture.

## Tech stack
- **Database:** PostgreSQL 15+, hosted on Supabase (decided — see rationale below).
- **Schema file:** `electroyachts_schema.sql` in this repo — apply it with
  the Supabase SQL Editor. This is the current source of truth for the
  data model; read it before writing any application code that touches
  the database. As of the last session it seeds ~54 manufacturers and
  ~110 models.
- **Frontend:** Next.js, single codebase deployed once (e.g. Vercel),
  serving MULTIPLE DOMAINS — see "Multi-domain architecture" below.
- **Why Supabase over Neon:** RLS policies in the schema are written for
  Supabase's `auth.users`/`auth.uid()` model, and its auto-generated
  REST/GraphQL API lets Claude Code (or any client) query data with no
  custom backend needed.

## Multi-domain architecture (decided)
The business targets multiple country/language markets via SEPARATE
DOMAINS (e.g. electroyachts.com, electroyachts.de, electroyachts.fr —
exact list TBD), not subfolders on one domain. Decision: **one shared
Next.js codebase and one deployment, serving all domains**, not a
separate project per domain.

- A domain → market mapping (which domain maps to which `language`/
  `country` in `content_pages`) lives in the app config, not the database.
- Middleware reads the incoming `Host` header on each request, resolves
  it to a language/country via that mapping, and queries `content_pages`
  filtered accordingly. `manufacturers` and `models` data is IDENTICAL
  across all domains (same underlying fleet of electric boats) — only
  the language layer (`content_pages`) and possibly country-specific
  content_page_groups differ.
- Add a new market by: adding a domain-to-market config entry, pointing
  DNS/custom domain at the same deployment, and populating
  `content_pages` rows for that language. No new codebase, no new
  deployment.
- **SEO requirement, do not skip:** since manufacturer/model data is
  shared verbatim across domains, implement `hreflang` tags linking
  equivalent pages across domains and a domain-specific `canonical` tag
  on every page. Without this, search engines may treat the sites as
  duplicate content across domains and suppress rankings.
- **Build order:** finish ONE domain end-to-end first (pick the primary
  one) as the template, verify it works well, THEN replicate the
  domain-mapping config for additional domains. Don't parallelize domain
  setup before the template is solid.

## Database model — quick orientation
Five core tables (deliberately scoped down from a larger 12-table plan —
the other 7, listed at the bottom of the .sql file, are deferred):

1. **manufacturers** — one row per boat builder. Key column: `product_line`
   enum (`electric_only` vs `mixed_electric_conventional`). Mixed
   manufacturers (Frauscher, Sunreef, Greenline, Axopar, Alfastreet, Boesch,
   Delphia, Four Winns, Hinckley, Nimbus, Rand Boats, Riva, Nautique, Zodiac
   Nautic) sell mostly combustion boats but have at least one electric
   model — don't assume everything from a "mixed" manufacturer is electric.
2. **models** — one row per boat model. Has a `propulsion_type` enum
   (`electric` / `hybrid_electric` / `conventional`) — **every seeded model
   so far is `electric`**, even ones from mixed manufacturers, because this
   site only lists the electric models.
3. **model_powertrains** — child table of `models`. This is the
   authoritative, queryable source for engine-level detail (motor brand/
   model, battery brand/kWh, charging time, speed/range for that specific
   configuration). Exists as a separate table because several models
   (Delphia 10, Rand Source 22, Alfastreet, Greenline) are sold with a
   *choice* of drivetrain on the same hull — one `models` row can have
   multiple `model_powertrains` rows. **Known simplification:** right now
   each drivetrain variant of those models exists as its own separate
   `models` row (e.g. "Delphia 10 (Electric)") instead of one canonical
   model with multiple powertrain rows. A cleaner refactor is flagged in
   the .sql file's closing notes — worth doing before the dataset grows
   much further.
4. **leads** — buyer inquiries. Contains PII — RLS restricts to staff only,
   no public read/write except an optional public-insert policy for
   contact-form submissions (commented out in the schema, add if needed).
5. **content_pages** (+ **content_page_groups**) — multilingual SEO content.
   One `content_page_groups` row per concept (e.g. "electric yachts Germany
   buyer guide"), with one `content_pages` row per language translation.
   Shared metadata (content type, target country, related manufacturer/
   model) lives on the group; title/slug/body/SEO metrics live per-language.

Also present: **deals** (sales pipeline, commission tracking — has a
generated `commission_amount_eur` column so it's always in sync).

## Row Level Security (Supabase)
- `manufacturers`, `models`, `model_powertrains`, `content_page_groups`,
  published `content_pages` → public read, staff-only write.
- `leads`, `deals` → staff-only, no public access (PII / commercial terms).
- Staff = rows in `staff_users` table, checked via `is_staff()` function.
- If deploying to Neon instead of Supabase: there's no built-in
  `auth.users`, so either skip the RLS section or swap the `staff_users`
  foreign key for a plain uuid fed by your own auth provider.

## Data provenance / what's verified vs. approximate
Seed data was researched via live web search (mid-2026), not generated from
training data. A few things to know before trusting a number:
- **Sunreef 80 Power Eco** battery capacity is intentionally `null` —
  it's bespoke per build, don't invent a figure for comparison pages.
- **Riva El-Iseo** is a prototype with no announced price — not yet
  purchasable, flag this if displayed on the site.
- Several prices were converted from GBP/USD to EUR at approximate rates
  and are marked as such in the model/powertrain `notes` column — re-verify
  before using in anything customer-facing (pricing pages, comparisons).
- Frauscher x Porsche price (€562k) came from a user-supplied competitive-
  landscape slide, not independently cross-verified — noted in that row.

## Domain portfolio (Phase 1)
Damyan owns ~61 domains for this project. Full mapping lives in
`domains.config.ts` — read that file for the authoritative list, don't
duplicate it here as it will drift out of sync. Summary of the decisions:

- **Global/umbrella brand:** `electricyachtmarket.com` — chosen as PRIMARY
  domain to build out fully first, per the "build one domain end-to-end
  before replicating" rule above. `electricyachts.co.uk` held in reserve
  for a UK-specific push later.
- **Phase 1 language domains (15):** one leading domain chosen per market
  from Damyan's purchased variants — always the non-hyphenated version,
  and always the ccTLD over .com where one was purchased. E.g.
  `elektrischeyachten.de` over `elektrische-yachten.de`/`.com`. The
  hyphenated/alternate-TLD variants Damyan also owns should 301-redirect
  to the chosen leading domain, not serve separate content.
- **Known gap:** no domain covers Norway, despite Norway being roughly
  tied with Germany for largest electric-boat market share in Europe
  (~22-24% vs Germany's ~32-34%, per Future Market Insights 2025 data).
  Worth acquiring a `.no` domain if Phase 2 expands.
- Corporate/holding-layer domains (`electricmarinegroup.com`, etc.) and
  single-vertical niche domains (`electricdayboats.com`,
  `electriccatamarans.eu`) exist in the portfolio but are NOT yet assigned
  a role in `domains.config.ts` — decide their purpose before Phase 2.

## Frontend scaffolding provided
Three starter files are included alongside this CLAUDE.md, ready to drop
into the Next.js app root:
- `domains.config.ts` — the domain-to-market mapping described above,
  plus a `resolveMarket()` helper.
- `middleware.ts` — reads the `Host` header on every request, resolves it
  via `resolveMarket()`, and forwards language/country as request headers
  (`x-market-language`, `x-market-country`, `x-market-hreflang`) so pages
  don't need to re-parse the domain themselves. Falls back to English if
  a domain isn't yet in the config, rather than erroring.
- `hreflang-tags.example.tsx` — `<HreflangTags>` and `<CanonicalTag>`
  components. MUST be included in every page once more than one domain is
  live — this is the SEO requirement flagged above, not optional polish.


- Schema designed and seeded: ~54 manufacturers (~65% electric-only, ~35%
  mixed), ~110 models, full powertrain detail for most of them, market_tier
  classification, discontinued models flagged.
- Database platform decided: Supabase.
- Multi-domain architecture decided: single Next.js codebase/deployment,
  domain-to-market config resolved via middleware — see above.
- No frontend built yet.
- No affiliate/commission agreements signed yet with any manufacturer
  except Crooze Yachts (EZ 28) — Damyan has full spec access and a
  commission agreement for this one. This is the model to prioritize in
  any early "featured manufacturer" or launch-partner placement.

## Next steps (in priority order)
1. Create the Supabase project, apply `electroyachts_schema.sql` via the
   SQL Editor, verify manufacturers/models tables populated correctly.
2. Scaffold the Next.js app: Supabase client setup, domain-to-market
   middleware, basic manufacturer/model listing pages reading real data.
3. Build out ONE domain fully (the primary one) as the template:
   manufacturer pages, model pages, comparison pages using
   `model_powertrains`, before replicating to other domains.
4. Implement hreflang + canonical tags before adding a second domain —
   this is an SEO requirement, not a nice-to-have, given shared
   manufacturer/model data across domains.
5. Populate initial `content_pages` rows for the primary domain's
   language/country.
6. Feature Crooze Yachts / EZ 28 prominently on launch — it's the only
   model with a live commission agreement.
7. Once the template domain is solid, add additional domains via the
   domain-mapping config + DNS, without duplicating the codebase.
8. Consider the `models` → `model_powertrains` refactor mentioned above
   before adding many more mixed-manufacturer models.
9. Longer-term: the 7 deferred tables (Domains/Local Markets, Comparisons,
   Partners, Offers/Quotes, Payments/Commissions, Media Library, Analytics)
   — add only when there's a concrete need, per the original scoping
   decision to start with 5 tables.

## Conventions / working style
- When adding new manufacturers or models, verify specs via web search
  rather than estimating — this dataset is meant to be trustworthy enough
  to publish, not just directionally correct.
- Keep `product_line` (manufacturer level) and `propulsion_type` (model
  level) both accurate and distinct — don't assume a manufacturer's
  product_line tells you a specific model's propulsion_type.
- Prices: note currency conversions explicitly rather than silently
  converting and presenting as if original.
