import type { InvitationTemplate } from './templates';

/** Escapes text for HTML element content and attribute values. */
export function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/** Strict page headers: no indexing, no referrer, inline styles only. */
export const GUEST_PAGE_HEADERS: Record<string, string> = {
  'Content-Type': 'text/html; charset=utf-8',
  'Cache-Control': 'no-store',
  'Referrer-Policy': 'no-referrer',
  'X-Robots-Tag': 'noindex, nofollow',
  'Content-Security-Policy':
    "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'",
};

const FONTS: Record<InvitationTemplate['headingFont'], string> = {
  serif: "Georgia, 'Times New Roman', serif",
  sans: "system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif",
  script: "'Brush Script MT', 'Segoe Script', cursive",
};

const ORNAMENTS: Record<InvitationTemplate['ornament'], string> = {
  none: '',
  lines: '— ✦ —',
  floral: '❀ ✿ ❀',
  diya: '🪔 ✦ 🪔',
  stars: '✧ ✦ ✧',
};

function shell(t: InvitationTemplate, title: string, body: string): string {
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>${escapeHtml(title)}</title>
<style>
body{margin:0;background:${t.background};color:${t.text};font-family:${FONTS.sans};line-height:1.5}
main{max-width:520px;margin:0 auto;padding:24px 16px 48px}
.card{background:${t.surface};border-radius:16px;padding:28px 20px;text-align:center;box-shadow:0 2px 12px rgba(0,0,0,.08)}
h1{font-family:${FONTS[t.headingFont]};font-size:2rem;margin:.4em 0;color:${t.accent}}
.orn{color:${t.accent};letter-spacing:.3em}
.muted{opacity:.8}
form{margin-top:24px;text-align:left;background:${t.surface};border-radius:16px;padding:20px}
label{display:block;font-weight:600;margin-top:12px}
input,select,textarea{width:100%;box-sizing:border-box;font:inherit;padding:10px;border-radius:8px;border:1px solid #bbb;margin-top:4px;background:#fff;color:#111}
fieldset{border:0;padding:0;margin:12px 0 0}
fieldset label{font-weight:400;display:inline-flex;gap:6px;margin-right:16px;align-items:center}
fieldset input{width:auto}
button{margin-top:20px;width:100%;padding:12px;border:0;border-radius:24px;background:${t.accent};color:${t.surface};font-size:1rem;font-weight:700}
.note{margin-top:16px;padding:12px;border-radius:8px;background:rgba(0,0,0,.06)}
.error{color:#b00020}
</style></head><body><main>${body}</main></body></html>`;
}

export interface GuestPageInvitation {
  template: InvitationTemplate;
  title: string;
  message: string | null;
  hostNames: string | null;
  eventDate: string;
  startTime: string | null;
  venueName: string | null;
  venueAddress: string | null;
  rsvpOpen: boolean;
}

export interface GuestPageRsvp {
  guestName: string;
  response: 'ATTENDING' | 'NOT_ATTENDING' | 'MAYBE';
  guestCount: number;
  message: string | null;
}

function formatDate(date: string): string {
  const d = new Date(`${date}T00:00:00Z`);
  return d.toLocaleDateString('en-IN', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    timeZone: 'UTC',
  });
}

function formatTime(time: string): string {
  const [h, m] = time.split(':').map(Number);
  const hour = ((h + 11) % 12) + 1;
  return `${hour}:${String(m).padStart(2, '0')} ${h < 12 ? 'AM' : 'PM'}`;
}

/** The invitation with its RSVP form (or a closed note). */
export function renderInvitationPage(
  inv: GuestPageInvitation,
  options: {
    formAction: string;
    existing: GuestPageRsvp | null;
    notice: 'sent' | 'invalid' | null;
  },
): string {
  const t = inv.template;
  const e = escapeHtml;
  const when = [
    formatDate(inv.eventDate),
    inv.startTime ? formatTime(inv.startTime) : null,
  ]
    .filter(Boolean)
    .join(' · ');
  const where = [inv.venueName, inv.venueAddress].filter(Boolean).join(', ');
  const r = options.existing;
  const checked = (value: GuestPageRsvp['response']) =>
    (r?.response ?? 'ATTENDING') === value ? ' checked' : '';
  const notice =
    options.notice === 'sent'
      ? `<p class="note" role="status">Thank you! Your reply was sent. You can change it below.</p>`
      : options.notice === 'invalid'
        ? `<p class="note error" role="alert">Please check your name and the number of guests (1–20).</p>`
        : '';
  const form = inv.rsvpOpen
    ? `<form method="post" action="${e(options.formAction)}">
<h2>Will you join us?</h2>${notice}
<label for="guestName">Your name</label>
<input id="guestName" name="guestName" required maxlength="80" value="${e(r?.guestName ?? '')}">
<fieldset><legend><b>Your reply</b></legend>
<label><input type="radio" name="response" value="ATTENDING"${checked('ATTENDING')}> Coming</label>
<label><input type="radio" name="response" value="MAYBE"${checked('MAYBE')}> Maybe</label>
<label><input type="radio" name="response" value="NOT_ATTENDING"${checked('NOT_ATTENDING')}> Not coming</label>
</fieldset>
<label for="guestCount">Number of guests (including you)</label>
<input id="guestCount" name="guestCount" type="number" min="1" max="20" value="${r?.guestCount ?? 1}">
<label for="message">Message (optional)</label>
<textarea id="message" name="message" maxlength="500" rows="3">${e(r?.message ?? '')}</textarea>
<button type="submit">${r ? 'Update my reply' : 'Send my reply'}</button>
</form>`
    : `<p class="note">Replies for this invitation are closed.</p>`;
  return shell(
    t,
    inv.title,
    `<section class="card">
<div class="orn" aria-hidden="true">${ORNAMENTS[t.ornament]}</div>
${inv.hostNames ? `<p class="muted">${e(inv.hostNames)} invite you to</p>` : ''}
<h1>${e(inv.title)}</h1>
<p><b>${e(when)}</b></p>
${where ? `<p>${e(where)}</p>` : ''}
${inv.message ? `<p>${e(inv.message).replace(/\n/g, '<br>')}</p>` : ''}
<div class="orn" aria-hidden="true">${ORNAMENTS[t.ornament]}</div>
</section>
${form}`,
  );
}

/** Unknown, revoked or deleted invitations: the same neutral page. */
export function renderUnavailablePage(): string {
  return shell(
    {
      code: 'minimal',
      name: 'Minimal',
      background: '#F5F5F5',
      surface: '#FFFFFF',
      text: '#1F1F1F',
      accent: '#1F1F1F',
      headingFont: 'sans',
      ornament: 'none',
    },
    'Invitation unavailable',
    `<section class="card"><h1>This invitation is no longer available</h1>
<p>Please check with the person who sent it.</p></section>`,
  );
}
