import nodemailer from 'nodemailer';
import { resolveLogoPath } from './otpEmail.js';

/**
 * Send transactional email for OTP flows.
 * Prefer Gmail SMTP when configured (can send to any address, no domain needed).
 * Fall back to Resend API (free tier only sends to the Resend account email
 * unless a custom domain is verified).
 *
 * @param {{ to: string, subject: string, text: string, html?: string, fromOverride?: string, embedLogo?: boolean }} opts
 */
export async function sendMail({ to, subject, text, html, fromOverride, embedLogo = true }) {
  const smtpUser = (process.env.SMTP_USER || process.env.GMAIL_USER || '').trim();
  const smtpPass = (process.env.SMTP_PASS || process.env.GMAIL_APP_PASSWORD || '').trim();
  const smtpHost = process.env.SMTP_HOST || 'smtp.gmail.com';
  const smtpPort = Number(process.env.SMTP_PORT || 465);

  const appUrl = (process.env.APP_URL || 'https://sanchivaorg.duckdns.org').replace(/\/$/, '');
  const forceEmbed = process.env.EMAIL_EMBED_LOGO === '1';
  const logoPath = embedLogo && forceEmbed ? resolveLogoPath() : null;
  const attachments = [];
  // Prefer hosted logo URL for smaller / more deliverable mail.
  // Set EMAIL_EMBED_LOGO=1 to attach CID instead.
  let htmlToSend = html;
  if (htmlToSend && !logoPath) {
    htmlToSend = htmlToSend.replace(/cid:sanchiva-logo/g, `${appUrl}/sanchiva-logo.png`);
  } else if (htmlToSend && logoPath) {
    attachments.push({
      filename: 'sanchiva-logo.png',
      path: logoPath,
      cid: 'sanchiva-logo',
    });
  }

  if (smtpUser && smtpPass) {
    const from =
      fromOverride ||
      process.env.SMTP_FROM ||
      process.env.SIGNUP_OTP_FROM ||
      process.env.PASSWORD_RESET_FROM ||
      `Sanchiva <${smtpUser}>`;

    const transporter = nodemailer.createTransport({
      host: smtpHost,
      port: smtpPort,
      secure: smtpPort === 465,
      auth: {
        user: smtpUser,
        pass: smtpPass.replace(/\s+/g, ''),
      },
    });

    const info = await transporter.sendMail({
      from,
      to,
      subject,
      text,
      html: htmlToSend || undefined,
      attachments: attachments.length ? attachments : undefined,
    });
    console.log(
      `[mail] smtp ok to=${to} subject="${subject}" id=${info.messageId || 'n/a'} response=${info.response || 'n/a'}`
    );
    return { delivered: true, provider: 'smtp', messageId: info.messageId };
  }

  const resendKey = process.env.RESEND_API_KEY;
  if (resendKey) {
    const from =
      fromOverride ||
      process.env.SIGNUP_OTP_FROM ||
      process.env.PASSWORD_RESET_FROM ||
      process.env.RESEND_FROM ||
      'Sanchiva <onboarding@resend.dev>';

    // Resend JSON API: use hosted logo URL instead of CID attachments
    const htmlForResend = htmlToSend
      ? htmlToSend.replace(/cid:sanchiva-logo/g, `${appUrl}/sanchiva-logo.png`)
      : undefined;

    const body = {
      from,
      to: [to],
      subject,
      text,
    };
    if (htmlForResend) body.html = htmlForResend;

    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${resendKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });
    if (!res.ok) {
      const errBody = await res.text();
      throw new Error(`Email send failed: ${res.status} ${errBody}`);
    }
    return { delivered: true, provider: 'resend' };
  }

  return { delivered: false, provider: null };
}
