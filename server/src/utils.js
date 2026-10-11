import { parseYmd, ymdFromParts } from './localDate.js';

/**
 * Sunday (week start) for a calendar DATE / YYYY-MM-DD.
 * Uses UTC-noon stepping so server TZ never flips the civil day.
 */
export function getWeekStart(dateInput) {
  const parsed = parseYmd(dateInput);
  let y;
  let m;
  let d;
  if (parsed) {
    y = parsed.year;
    m = parsed.month;
    d = parsed.day;
  } else {
    const x = new Date(dateInput);
    y = x.getUTCFullYear();
    m = x.getUTCMonth() + 1;
    d = x.getUTCDate();
  }
  const dt = new Date(Date.UTC(y, m - 1, d, 12));
  const dow = dt.getUTCDay(); // 0 = Sunday
  dt.setUTCDate(dt.getUTCDate() - dow);
  // Return a Date at UTC noon so formatDate can read UTC parts safely.
  return dt;
}

export function formatDate(d) {
  const parsed = parseYmd(d);
  if (parsed) return parsed.ymd;
  if (d instanceof Date && !Number.isNaN(d.getTime())) {
    // Prefer UTC parts for Dates produced by getWeekStart (UTC noon).
    return ymdFromParts(d.getUTCFullYear(), d.getUTCMonth() + 1, d.getUTCDate());
  }
  const x = new Date(d);
  return ymdFromParts(x.getUTCFullYear(), x.getUTCMonth() + 1, x.getUTCDate());
}

export function monthsBetween(startMonth, startYear, endMonth, endYear) {
  return (endYear - startYear) * 12 + (endMonth - startMonth) + 1;
}

export function loanProgress(loan, asOf = new Date()) {
  const startM = loan.start_month || 1;
  const startY = loan.start_year || asOf.getFullYear();
  const closeM = loan.emi_close_month;
  const closeY = loan.emi_close_year;
  const emi = Number(loan.emi_amount);

  const totalMonths = monthsBetween(startM, startY, closeM, closeY);
  const totalAmount = emi * Math.max(totalMonths, 0);

  if (loan.status === 'closed') {
    return {
      totalAmount,
      deducted: totalAmount,
      remaining: 0,
      totalMonths,
      monthsPaid: totalMonths,
      monthsLeft: 0,
    };
  }

  const asOfM = asOf.getMonth() + 1;
  const asOfY = asOf.getFullYear();
  let monthsPaid = monthsBetween(startM, startY, asOfM, asOfY);
  if (monthsPaid < 0) monthsPaid = 0;
  if (monthsPaid > totalMonths) monthsPaid = totalMonths;

  const deducted = emi * monthsPaid;
  const remaining = Math.max(totalAmount - deducted, 0);

  return {
    totalAmount,
    deducted,
    remaining,
    totalMonths,
    monthsPaid,
    monthsLeft: Math.max(totalMonths - monthsPaid, 0),
  };
}

export function isEmiActiveInMonth(startM, startY, endM, endY, month, year) {
  const start = startY * 12 + startM;
  const end = endY * 12 + endM;
  const cur = year * 12 + month;
  return cur >= start && cur <= end;
}
