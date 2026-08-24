import nodemailer from 'nodemailer';

/**
 * Send transactional OTP email.
 * Prefer Gmail SMTP when configured.
 * Fall back to Resend API when SMTP is not set.
 *
 * Deliverability notes (no custom domain):
 * - Avoid remote images / duckdns links (spam trigger)
 * - Keep content short and personal
 * - Mark as transactional / auto-generated
 * Inbox placement still cannot be guaranteed without SPF/DKIM on your own domain.
 */
export async function sendMail({ to, subject, text, html, fromOverride }) {
  const smtpUser = (process.env.SMTP_USER || process.env.GMAIL_USER || '').trim();
  const smtpPass = (process.env.SMTP_PASS || process.env.GMAIL_APP_PASSWORD || '').trim();
  const smtpHost = process.env.SMTP_HOST || 'smtp.gmail.com';
  const smtpPort = Number(process.env.SMTP_PORT || 465);

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
      replyTo: smtpUser,
      subject,
      // Text first — multipart alternative with text preferred by many filters.
      text,
      html: html || undefined,
      headers: {
        'Auto-Submitted': 'auto-generated',
        'X-Auto-Response-Suppress': 'All',
        'X-Mailer': 'Sanchiva',
      },
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

    const body = {
      from,
      to: [to],
      subject,
      text,
    };
    if (html) body.html = html;

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
