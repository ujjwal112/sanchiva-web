import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const BRAND = '#5038F0';
const BRAND_DEEP = '#7A40F8';

/** Resolve logo file for CID embedding (Docker: /app/client/dist, local: ../../client/public). */
export function resolveLogoPath() {
  const candidates = [
    path.resolve(__dirname, '../../../client/dist/sanchiva-logo.png'),
    path.resolve(__dirname, '../../../client/public/sanchiva-logo.png'),
    path.resolve(__dirname, '../../../client/dist/sanchiva-logo.jpg'),
    path.resolve(__dirname, '../../../client/public/sanchiva-logo.jpg'),
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

function logoBlock(logoSrc) {
  if (!logoSrc) {
    return `
      <div style="width:64px;height:64px;border-radius:16px;margin:0 auto 12px;background:linear-gradient(135deg,${BRAND},${BRAND_DEEP});line-height:64px;text-align:center;color:#ffffff;font-size:28px;font-weight:800;font-family:Arial,Helvetica,sans-serif;">S</div>
    `;
  }
  return `
    <img src="${logoSrc}" width="72" height="72" alt="Sanchiva" style="display:block;margin:0 auto 12px;width:72px;height:72px;border:0;outline:none;text-decoration:none;border-radius:16px;" />
  `;
}

/**
 * Build HTML + text OTP email.
 * @param {{ otp: string, purpose?: 'signup'|'reset', name?: string, logoSrc?: string }} opts
 * logoSrc: 'cid:sanchiva-logo' when attaching, or absolute https URL
 */
export function buildOtpEmail({ otp, purpose = 'signup', name, logoSrc }) {
  const isReset = purpose === 'reset';
  const title = isReset ? 'Reset your password' : 'Verify your email';
  const greeting = name ? `Hi ${escapeHtml(name)},` : 'Hi there,';
  const intro = isReset
    ? 'Use this code to set a new password for your Sanchiva account.'
    : 'Use this code to finish creating your Sanchiva account.';
  const subject = isReset ? 'Your Sanchiva password reset code' : 'Your Sanchiva verification code';

  const code = String(otp || '').trim();
  const logo = logoBlock(logoSrc || null);

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${escapeHtml(subject)}</title>
</head>
<body style="margin:0;padding:0;background:#F3F0FF;font-family:Arial,Helvetica,sans-serif;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#F3F0FF;padding:32px 16px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:480px;background:#ffffff;border-radius:20px;overflow:hidden;box-shadow:0 8px 28px rgba(80,56,240,0.12);">
          <tr>
            <td style="background:linear-gradient(135deg,${BRAND} 0%,${BRAND_DEEP} 100%);padding:28px 24px;text-align:center;">
              ${logo}
              <div style="color:#ffffff;font-size:26px;font-weight:800;letter-spacing:0.3px;line-height:1.2;">Sanchiva</div>
            </td>
          </tr>
          <tr>
            <td style="padding:32px 28px 12px;text-align:center;">
              <div style="color:#1F1635;font-size:20px;font-weight:700;margin-bottom:10px;">${escapeHtml(title)}</div>
              <div style="color:#6B6280;font-size:15px;line-height:1.5;margin-bottom:8px;">${escapeHtml(greeting)}</div>
              <div style="color:#6B6280;font-size:15px;line-height:1.5;">${escapeHtml(intro)}</div>
            </td>
          </tr>
          <tr>
            <td align="center" style="padding:20px 28px 8px;">
              <div style="display:inline-block;background:#F4F1FF;border:1px solid #E4DCFF;border-radius:16px;padding:18px 28px;min-width:220px;">
                <div style="color:#8B83A3;font-size:12px;font-weight:700;letter-spacing:1.2px;text-transform:uppercase;margin-bottom:10px;text-align:center;">Your code</div>
                <div style="color:${BRAND};font-size:40px;font-weight:800;letter-spacing:10px;line-height:1.2;text-align:center;font-family:'Courier New',Courier,monospace;">${escapeHtml(code)}</div>
              </div>
            </td>
          </tr>
          <tr>
            <td style="padding:18px 28px 32px;text-align:center;">
              <div style="color:#8B83A3;font-size:13px;line-height:1.5;">This code expires in 15 minutes.</div>
              <div style="color:#A59BB8;font-size:12px;line-height:1.5;margin-top:8px;">If you did not request this, you can ignore this email.</div>
            </td>
          </tr>
        </table>
        <div style="max-width:480px;color:#A59BB8;font-size:11px;text-align:center;padding:16px 8px 0;">Sent by Sanchiva</div>
      </td>
    </tr>
  </table>
</body>
</html>`;

  const text = [
    'Sanchiva',
    '',
    greeting,
    intro,
    '',
    `Your code: ${code}`,
    '',
    'This code expires in 15 minutes.',
    'If you did not request this, you can ignore this email.',
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
