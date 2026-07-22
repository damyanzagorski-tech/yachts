import { Resend } from 'resend';

/**
 * Emails Damyan when a new lead lands, via Resend.
 *
 * Configuration (env):
 * - RESEND_API_KEY     — required for sending; when absent this is a no-op
 *                        (form keeps working, a warning is logged).
 * - LEAD_NOTIFY_TO     — recipient; defaults to the founder inbox.
 * - LEAD_NOTIFY_FROM   — sender; defaults to Resend's onboarding sender,
 *                        which only delivers to the Resend account owner.
 *                        Switch to leads@electricyachtmarket.com once the
 *                        domain is verified in the Resend dashboard.
 *
 * Failures are logged, never thrown — a lost email must not lose the lead
 * (the row is already in Supabase by the time this runs).
 */
export type LeadNotification = {
  fullName: string;
  email: string;
  phone: string | null;
  country: string | null;
  timeframe: string | null;
  message: string | null;
  modelName: string | null;
  sourceDomain: string | null;
  language: string;
};

const esc = (s: string) =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

export async function notifyLead(lead: LeadNotification): Promise<void> {
  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) {
    console.warn('RESEND_API_KEY not set — lead notification email skipped.');
    return;
  }

  const to = process.env.LEAD_NOTIFY_TO ?? 'damyanzagorski@gmail.com';
  const from = process.env.LEAD_NOTIFY_FROM ?? 'Electric Yacht Market <onboarding@resend.dev>';

  const subjectModel = lead.modelName ? ` — ${lead.modelName}` : '';
  const rows: [string, string | null][] = [
    ['Name', lead.fullName],
    ['Email', lead.email],
    ['Phone', lead.phone],
    ['Country', lead.country],
    ['Timeframe', lead.timeframe],
    ['Model', lead.modelName],
    ['Site', lead.sourceDomain],
    ['Language', lead.language],
  ];

  const html = `
    <h2 style="font-family:Georgia,serif;font-weight:normal">New lead${esc(subjectModel)}</h2>
    <table cellpadding="6" style="font-family:sans-serif;font-size:14px;border-collapse:collapse">
      ${rows
        .filter(([, v]) => v)
        .map(
          ([k, v]) =>
            `<tr><td style="color:#888;padding-right:16px">${k}</td><td><b>${esc(v!)}</b></td></tr>`,
        )
        .join('')}
    </table>
    ${lead.message ? `<p style="font-family:sans-serif;font-size:14px;white-space:pre-wrap;border-left:3px solid #c46b3a;padding-left:12px">${esc(lead.message)}</p>` : ''}
    <p style="font-family:sans-serif;font-size:12px;color:#888">Full record is in the Supabase leads table.</p>
  `;

  try {
    const resend = new Resend(apiKey);
    const { error } = await resend.emails.send({
      from,
      to,
      replyTo: lead.email,
      subject: `New lead${subjectModel} (${lead.fullName})`,
      html,
    });
    if (error) console.error('Lead notification email failed:', error);
  } catch (err) {
    console.error('Lead notification email threw:', err);
  }
}
