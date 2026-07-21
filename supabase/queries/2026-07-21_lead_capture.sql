-- Lead capture: public contact form on model pages.
-- Applied via: npx supabase db query --linked -f supabase/queries/2026-07-21_lead_capture.sql
-- Mirrored into electroyachts_schema.sql in the same commit.

-- GDPR: record when the visitor ticked the consent checkbox (required
-- field on the public form; EU audience).
alter table leads
  add column if not exists gdpr_consent_at timestamptz;

-- The public form's server action inserts with the anon key. INSERT only —
-- SELECT/UPDATE/DELETE stay staff-only via the existing leads_staff_only
-- policy. This is the policy sketched in the schema's RLS notes.
-- with check constrains inserts to fresh, unscored rows so the anon role
-- can't inject pre-qualified/scored leads.
create policy "leads_public_insert"
on leads for insert
to anon
with check (status = 'new' and lead_score = 0);
