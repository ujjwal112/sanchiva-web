/**
 * Client calendar day helpers.
 *
 * Mobile sends `X-Client-Local-Date: YYYY-MM-DD` (phone local midnight boundary).
 * Fall back to Asia/Kolkata when the header is missing (web / old clients).
 */

const YMD_RE = /^(\d{4})-(\d{2})-(\d{2})$/;

function ymdFromParts(year, month, day) {
  return `${String(year).padStart(4, '0')}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
}

/** Today in Asia/Kolkata as YYYY-MM-DD (server fallback). */
export function istTodayYmd() {
  const fmt = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Kolkata',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  return fmt.format(new Date()); // en-CA → YYYY-MM-DD
}

/**
 * Resolve the caller's calendar day from header / query, else IST.
 * @returns {{ ymd: string, year: number, month: number, day: number }}
 */
export function clientLocalDate(req) {
  const raw = String(
    (req && (req.get?.('x-client-local-date') || req.headers?.['x-client-local-date'])) ||
      (req && req.query && req.query.localDate) ||
      ''
  )
    .trim()
    .slice(0, 10);

  if (YMD_RE.test(raw)) {
    const [, ys, ms, ds] = raw.match(YMD_RE);
    const year = Number(ys);
    const month = Number(ms);
    const day = Number(ds);
    return { ymd: raw, year, month, day };
  }

  const ymd = istTodayYmd();
  const [year, month, day] = ymd.split('-').map(Number);
  return { ymd, year, month, day };
}

/** Parse a DATE / YYYY-MM-DD string into calendar parts (no timezone shift). */
export function parseYmd(value) {
  const s = String(value || '').trim().slice(0, 10);
  if (YMD_RE.test(s)) {
    const [, ys, ms, ds] = s.match(YMD_RE);
    return { ymd: s, year: Number(ys), month: Number(ms), day: Number(ds) };
  }
  return null;
}

export function addDaysYmd(ymd, deltaDays) {
  const p = parseYmd(ymd);
  if (!p) return ymd;
  // Noon UTC avoids DST edge cases when stepping calendar days.
  const dt = new Date(Date.UTC(p.year, p.month - 1, p.day, 12));
  dt.setUTCDate(dt.getUTCDate() + Number(deltaDays || 0));
  return ymdFromParts(dt.getUTCFullYear(), dt.getUTCMonth() + 1, dt.getUTCDate());
}

export { ymdFromParts };
