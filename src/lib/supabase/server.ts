import { createClient } from '@supabase/supabase-js';
import type { Database } from './types';

/**
 * Server-side Supabase client for Server Components / route handlers.
 * Uses the public anon key — RLS policies (see electroyachts_schema.sql)
 * enforce what's actually readable, so this is safe to use for the public
 * manufacturers/models/content_pages listing pages.
 */
export function createSupabaseServerClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!url || !anonKey) {
    throw new Error(
      'Missing NEXT_PUBLIC_SUPABASE_URL / NEXT_PUBLIC_SUPABASE_ANON_KEY. ' +
        'Copy .env.local.example to .env.local and fill in your Supabase project credentials.'
    );
  }

  return createClient<Database>(url, anonKey);
}
