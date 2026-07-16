'use client';

import { createClient } from '@supabase/supabase-js';
import type { Database } from './types';

/**
 * Browser-side Supabase client, for Client Components that need
 * interactivity (e.g. a lead/contact form). Public anon key only —
 * never import the service role key into anything shipped to the browser.
 */
export function createSupabaseBrowserClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL!;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;
  return createClient<Database>(url, anonKey);
}
