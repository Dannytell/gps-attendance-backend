/**
 * Unified mailer utility.
 *
 * Render.com (and most cloud hosts) block outbound SMTP ports (25, 465, 587),
 * which causes `ETIMEDOUT` errors when using nodemailer directly with Gmail.
 *
 * This utility sends mail via an HTTPS API when available (port 443 is never
 * blocked) and transparently falls back to SMTP for local development.
 *
 * Priority order:
 *   1. Resend    — if RESEND_API_KEY is set  (recommended for production)
 *   2. Brevo     — if BREVO_API_KEY  is set
 *   3. SMTP      — nodemailer fallback (works locally, fails on Render)
 *
 * Required env vars for production (Render):
 *   RESEND_API_KEY   = re_xxxxxxxxxxxxxxxxxxxx
 *   MAIL_FROM        = "NEO-EDU <noreply@yourdomain.com>"   (must be a
 *                      verified domain on Resend, OR use the default
 *                      "onboarding@resend.dev" sandbox address for testing)
 */

const nodemailer = require('nodemailer');

const FROM_ADDRESS =
  process.env.MAIL_FROM ||
  `NEO-EDU <${process.env.SMTP_EMAIL || 'onboarding@resend.dev'}>`;

// --- Provider: Resend (HTTP) ---------------------------------------------
async function sendViaResend({ to, subject, text, html }) {
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: FROM_ADDRESS,
      to: Array.isArray(to) ? to : [to],
      subject,
      text,
      html,
    }),
  });

  if (!res.ok) {
    const errBody = await res.text();
    throw new Error(`Resend API error (${res.status}): ${errBody}`);
  }
  return res.json();
}

// --- Provider: Brevo (HTTP) ----------------------------------------------
async function sendViaBrevo({ to, subject, text, html }) {
  // Extract "name" and "email" portions from FROM_ADDRESS  ("Name <email>")
  const match = FROM_ADDRESS.match(/^\s*(?:"?([^"<]+)"?\s*)?<?([^>]+)>?\s*$/);
  const fromName = (match && match[1]) ? match[1].trim() : 'NEO-EDU';
  const fromEmail = (match && match[2]) ? match[2].trim() : FROM_ADDRESS;

  const res = await fetch('https://api.brevo.com/v3/smtp/email', {
    method: 'POST',
    headers: {
      'api-key': process.env.BREVO_API_KEY,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify({
      sender: { name: fromName, email: fromEmail },
      to: [{ email: to }],
      subject,
      textContent: text,
      htmlContent: html,
    }),
  });

  if (!res.ok) {
    const errBody = await res.text();
    throw new Error(`Brevo API error (${res.status}): ${errBody}`);
  }
  return res.json();
}

// --- Provider: SMTP (fallback for local dev) -----------------------------
let smtpTransporter = null;
function getSmtpTransporter() {
  if (smtpTransporter) return smtpTransporter;
  smtpTransporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST || 'smtp.gmail.com',
    port: Number(process.env.SMTP_PORT) || 587,
    secure: (Number(process.env.SMTP_PORT) || 587) === 465,
    auth: {
      user: process.env.SMTP_EMAIL,
      pass: process.env.SMTP_PASSWORD,
    },
    tls: { rejectUnauthorized: false },
    connectionTimeout: 10_000,
    greetingTimeout: 10_000,
    socketTimeout: 15_000,
  });
  return smtpTransporter;
}

async function sendViaSmtp({ to, subject, text, html }) {
  const t = getSmtpTransporter();
  return t.sendMail({ from: FROM_ADDRESS, to, subject, text, html });
}

/**
 * Send an email via the best available provider.
 * @param {{to:string, subject:string, text?:string, html?:string}} opts
 * @returns {Promise<{provider:string, info:any}>}
 */
async function sendMail(opts) {
  if (!opts || !opts.to || !opts.subject) {
    throw new Error('sendMail: "to" and "subject" are required');
  }

  if (process.env.RESEND_API_KEY) {
    const info = await sendViaResend(opts);
    return { provider: 'resend', info };
  }
  if (process.env.BREVO_API_KEY) {
    const info = await sendViaBrevo(opts);
    return { provider: 'brevo', info };
  }
  if (process.env.SMTP_EMAIL && process.env.SMTP_PASSWORD) {
    const info = await sendViaSmtp(opts);
    return { provider: 'smtp', info };
  }

  throw new Error(
    'No email provider configured. Set RESEND_API_KEY (recommended) ' +
      'or BREVO_API_KEY, or SMTP_EMAIL + SMTP_PASSWORD for local dev.'
  );
}

module.exports = { sendMail };
