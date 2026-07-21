'use client';

import { useActionState, useState } from 'react';
import { submitLead, type LeadFormState } from '@/lib/leads/submitLead';

const inputClass =
  'w-full rounded-md border border-rule bg-ink-2 px-3 py-2 text-sm text-paper placeholder:text-muted focus:border-copper focus:outline-none';

const labelClass = 'mb-1.5 block text-xs font-semibold uppercase tracking-[0.16em] text-muted';

/**
 * Public enquiry form shown on model detail pages. Submits through the
 * submitLead server action; includes a honeypot + render-timestamp for
 * spam filtering and a required GDPR consent checkbox.
 */
export function LeadForm({ modelId, modelName }: { modelId: string; modelName: string }) {
  const [state, formAction, pending] = useActionState<LeadFormState, FormData>(submitLead, {
    status: 'idle',
  });
  // Stamped once on mount; the server rejects submissions faster than 3s.
  const [renderedAt] = useState(() => Date.now());

  if (state.status === 'success') {
    return (
      <div className="rounded-lg border border-rule bg-ink-2 p-6">
        <p className="font-serif text-xl font-light">Thank you — enquiry received.</p>
        <p className="mt-2 text-sm text-muted">
          We&apos;ll come back to you about the {modelName} as soon as possible, usually within one
          business day.
        </p>
      </div>
    );
  }

  return (
    <form action={formAction} className="rounded-lg border border-rule bg-ink-2 p-6">
      <h2 className="font-serif text-xl font-light">
        Enquire about the <em className="text-copper">{modelName}</em>
      </h2>
      <p className="mt-1 text-sm text-muted">
        Pricing, availability, sea trials — we&apos;ll connect you with the builder.
      </p>

      <input type="hidden" name="model_id" value={modelId} />
      <input type="hidden" name="rendered_at" value={renderedAt} />
      {/* Honeypot — hidden from real users, bots fill it */}
      <div className="absolute -left-[9999px] top-auto" aria-hidden="true">
        <label>
          Website
          <input type="text" name="website" tabIndex={-1} autoComplete="off" />
        </label>
      </div>

      <div className="mt-5 grid gap-4 sm:grid-cols-2">
        <div>
          <label htmlFor="lead-name" className={labelClass}>
            Name *
          </label>
          <input id="lead-name" name="full_name" required maxLength={200} className={inputClass} />
        </div>
        <div>
          <label htmlFor="lead-email" className={labelClass}>
            Email *
          </label>
          <input id="lead-email" name="email" type="email" required maxLength={320} className={inputClass} />
        </div>
        <div>
          <label htmlFor="lead-phone" className={labelClass}>
            Phone
          </label>
          <input id="lead-phone" name="phone" type="tel" maxLength={40} className={inputClass} />
        </div>
        <div>
          <label htmlFor="lead-country" className={labelClass}>
            Country
          </label>
          <input id="lead-country" name="country" maxLength={80} className={inputClass} />
        </div>
        <div className="sm:col-span-2">
          <label htmlFor="lead-timeframe" className={labelClass}>
            Purchase timeframe
          </label>
          <select id="lead-timeframe" name="purchase_timeframe" defaultValue="" className={inputClass}>
            <option value="">Select…</option>
            <option value="0-3 months">0–3 months</option>
            <option value="3-6 months">3–6 months</option>
            <option value="6-12 months">6–12 months</option>
            <option value="12+ months">12+ months</option>
            <option value="just researching">Just researching</option>
          </select>
        </div>
        <div className="sm:col-span-2">
          <label htmlFor="lead-message" className={labelClass}>
            Message
          </label>
          <textarea
            id="lead-message"
            name="message"
            rows={4}
            maxLength={4000}
            placeholder="Tell us about your intended use, preferred configuration, questions…"
            className={inputClass}
          />
        </div>
      </div>

      <label className="mt-4 flex cursor-pointer items-start gap-2.5 text-xs text-muted">
        <input type="checkbox" name="gdpr_consent" required className="mt-0.5 accent-copper" />
        <span>
          I agree that my details will be processed to handle this enquiry and passed to the relevant
          manufacturer or dealer. *
        </span>
      </label>

      {state.status === 'error' && (
        <p className="mt-4 rounded-md border border-copper-soft bg-ink px-3 py-2 text-sm text-copper-soft">
          {state.message}
        </p>
      )}

      <button
        type="submit"
        disabled={pending}
        className="mt-5 rounded-full bg-copper px-6 py-2.5 text-sm font-semibold uppercase tracking-[0.1em] text-paper transition-colors hover:bg-copper-soft disabled:cursor-not-allowed disabled:opacity-60"
      >
        {pending ? 'Sending…' : 'Send enquiry'}
      </button>
    </form>
  );
}
