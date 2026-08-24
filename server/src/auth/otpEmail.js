import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const BRAND = '#5038F0';

/** Resolve logo file for optional CID embedding. */
export function resolveLogoPath() {
  const candidates = [
    path.resolve(__dirname, '../../../client/dist/sanchiva-logo.png'),
    path.resolve(__dirname, '../../../client/public/sanchiva-logo.png'),
  ];
  for (const p of candidates) {
    try {
      if (fs.existsSync(p)) return p;
    } catch {
      /* ignore */
    }
  }
  return null;
}

/**
 * Build deliverability-first OTP email (text + light HTML, no external images/links).
 * External duckdns image URLs are a common spam trigger — avoided on purpose.
 */
export function buildOtpEmail({ otp, purpose = 'signup', name }) {
  const isReset = purpose === 'reset';
  const greetingPlain = name ? `Hi ${String(name).trim()},` : 'Hi,';
  const introPlain = isReset
    ? 'Here is your Sanchiva password reset code:'
    : 'Here is your Sanchiva signup code:';
  // Short, personal subjects land better than marketing-style "verification" subjects.
  const subject = isReset ? 'Sanchiva password reset code' : 'Sanchiva signup code';

  const code = String(otp || '').trim();

  // Minimal HTML — looks like a simple note, not a campaign.
  // No remote images, no tracking pixels, no duckdns / website links.
  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${escapeHtml(subject)}</title>
</head>
<body style="margin:0;padding:24px;background:#ffffff;font-family:Arial,Helvetica,sans-serif;color:#222222;">
  <div style="max-width:440px;margin:0 auto;">
    <div style="font-size:20px;font-weight:700;color:${BRAND};margin-bottom:20px;">Sanchiva</div>
    <p style="margin:0 0 12px;font-size:15px;line-height:1.5;">${escapeHtml(greetingPlain)}</p>
    <p style="margin:0 0 16px;font-size:15px;line-height:1.5;">${escapeHtml(introPlain)}</p>
    <p style="margin:0 0 20px;font-size:32px;font-weight:700;letter-spacing:8px;color:#111111;text-align:center;">${escapeHtml(code)}</p>
    <p style="margin:0 0 8px;font-size:13px;line-height:1.5;color:#555555;">This code expires in 15 minutes.</p>
    <p style="margin:0;font-size:13px;line-height:1.5;color:#555555;">If you did not ask for this, you can ignore this message.</p>
  </div>
</body>
</html>`;

  const text = [
    'Sanchiva',
    '',
    greetingPlain,
    introPlain,
    '',
    code,
    '',
    'This code expires in 15 minutes.',
    'If you did not ask for this, you can ignore this message.',
  ].join('\n');

  return { subject, html, text };
}

function escapeHtml(s) {
  return String(s || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
