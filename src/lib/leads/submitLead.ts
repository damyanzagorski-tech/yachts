'use server';

import { headers } from 'next/headers';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { notifyLead } from '@/lib/leads/notifyLead';

export type LeadFormState = {
  status: 'idle' | 'success' | 'error';
  message?: string;
};

const TIMEFRAMES = new Set(['0-3 months', '3-6 months', '6-12 months', '12+ months', 'just researching']);

/**
 * Server action behind the public enquiry form on model pages. Inserts via
 * the anon key under the narrow leads_public_insert RLS policy (INSERT
 * only, status='new', lead_score=0 — reads stay staff-only).
 *
 * Spam defences: hidden honeypot field ("website") and a minimum-fill-time
 * check (forms submitted <3s after render are dropped). Both fail
 * silently with a fake success so bots don't learn.
 */
export async function submitLead(_prev: LeadFormState, formData: FormData): Promise<LeadFormState> {
  // Honeypot: real users never see or fill this field.
  if ((formData.get('website') as string)?.trim()) {
    return { status: 'success' };
  }
  // Bots submit instantly; humans take longer than 3 seconds.
  const renderedAt = Number(formData.get('rendered_at'));
  if (!Number.isFinite(renderedAt) || Date.now() - renderedAt < 3000) {
    return { status: 'success' };
  }

  const fullName = (formData.get('full_name') as string)?.trim() ?? '';
  const email = (formData.get('email') as string)?.trim() ?? '';
  const phone = (formData.get('phone') as string)?.trim() || null;
  const country = (formData.get('country') as string)?.trim() || null;
  const message = (formData.get('message') as string)?.trim() || null;
  const timeframeRaw = (formData.get('purchase_timeframe') as string) || '';
  const consent = formData.get('gdpr_consent') === 'on';
  const modelId = (formData.get('model_id') as string) || null;

  if (!fullName || fullName.length > 200) {
    return { status: 'error', message: 'Please enter your name.' };
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email) || email.length > 320) {
    return { status: 'error', message: 'Please enter a valid email address.' };
  }
  if (!consent) {
    return { status: 'error', message: 'Please accept the privacy terms so we can process your enquiry.' };
  }
  if (message && message.length > 4000) {
    return { status: 'error', message: 'Message is too long (4000 characters max).' };
  }

  const requestHeaders = await headers();
  const language = requestHeaders.get('x-market-language') ?? 'en';
  const host = requestHeaders.get('host') ?? null;

  try {
    const supabase = createSupabaseServerClient();
    const { error } = await supabase.from('leads').insert({
      full_name: fullName,
      email,
      phone,
      country,
      preferred_language: language,
      interested_model_id: modelId,
      purchase_timeframe: TIMEFRAMES.has(timeframeRaw) ? timeframeRaw : null,
      source: 'organic_seo',
      source_domain: host,
      notes: message,
      gdpr_consent_at: new Date().toISOString(),
      status: 'new',
      lead_score: 0,
    });

    if (error) {
      console.error('Lead insert failed:', error.message);
      return { status: 'error', message: 'Something went wrong — please try again or email us directly.' };
    }

    // Awaited (serverless may freeze after return) but never throws —
    // a failed email must not fail the submission; the row is already saved.
    let modelName: string | null = null;
    if (modelId) {
      const { data: model } = await supabase.from('models').select('name').eq('id', modelId).maybeSingle();
      modelName = model?.name ?? null;
    }
    await notifyLead({
      fullName,
      email,
      phone,
      country,
      timeframe: TIMEFRAMES.has(timeframeRaw) ? timeframeRaw : null,
      message,
      modelName,
      sourceDomain: host,
      language,
    });

    return { status: 'success' };
  } catch (err) {
    console.error('Lead insert threw:', err);
    return { status: 'error', message: 'Something went wrong — please try again or email us directly.' };
  }
}
