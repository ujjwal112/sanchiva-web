import nodemailer from 'nodemailer';

/**
 * Send transactional email for OTP flows.
 * Prefer Gmail SMTP when configured (can send to any address, no domain needed).
 * Fall back to Resend API (free tier only sends to the Resend account email
 * unless a custom domain is verified).
 */
export async function sendMail({ to, subject, text, fromOverride }) {
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
        pass: smtpPass.replace(/\s+/g, ''), // allow pasted "xxxx xxxx xxxx xxxx"
      },
    });

    await transporter.sendMail({
      from,
      to,
      subject,
      text,
    });
    return { delivered: true, provider: 'smtp' };
  }

  const resendKey = process.env.RESEND_API_KEY;
  if (resendKey) {
    const from =
      fromOverride ||
      process.env.SIGNUP_OTP_FROM ||
      process.env.PASSWORD_RESET_FROM ||
      process.env.RESEND_FROM ||
      'Sanchiva <onboarding@resend.dev>';

    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${resendKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from,
        to: [to],
        subject,
        text,
      }),
    });
    if (!res.ok) {
      const body = await res.text();
      throw new Error(`Email send failed: ${res.status} ${body}`);
    }
    return { delivered: true, provider: 'resend' };
  }

  return { delivered: false, provider: null };
}
