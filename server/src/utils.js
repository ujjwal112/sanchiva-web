/** Get Sunday (week start) for a given date */
export function getWeekStart(dateInput) {
  const d = new Date(dateInput);
  const day = d.getDay(); // 0 = Sunday
  const start = new Date(d);
  start.setDate(d.getDate() - day);
  start.setHours(0, 0, 0, 0);
  return start;
}

export function formatDate(d) {
  const x = new Date(d);
  const y = x.getFullYear();
  const m = String(x.getMonth() + 1).padStart(2, '0');
  const day = String(x.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
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
