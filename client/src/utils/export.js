import * as XLSX from 'xlsx';
import { jsPDF } from 'jspdf';
import autoTable from 'jspdf-autotable';

/** Flatten rows using column export config: { key, label, export?: (row) => any } */
export function rowsToMatrix(columns, rows) {
  const headers = columns.map((c) => c.label);
  const data = rows.map((row) =>
    columns.map((c) => {
      let val;
      if (typeof c.export === 'function') val = c.export(row);
      else val = row[c.key];
      if (val == null) return '';
      if (val instanceof Date) return val.toISOString().slice(0, 10);
      return typeof val === 'object' ? String(val) : val;
    })
  );
  return { headers, data };
}

export function downloadExcel({ columns, rows, filename = 'export', sheetName = 'Data' }) {
  const { headers, data } = rowsToMatrix(columns, rows);
  const ws = XLSX.utils.aoa_to_sheet([headers, ...data]);
  const colWidths = headers.map((h, i) => {
    const maxLen = Math.max(String(h).length, ...data.map((r) => String(r[i] ?? '').length));
    return { wch: Math.min(Math.max(maxLen + 2, 10), 40) };
  });
  ws['!cols'] = colWidths;
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, sheetName.slice(0, 31));
  XLSX.writeFile(wb, `${filename}.xlsx`);
}

/** Multi-sheet excel */
export function downloadExcelMulti({ sheets, filename = 'export' }) {
  const wb = XLSX.utils.book_new();
  for (const sheet of sheets) {
    const { headers, data } = rowsToMatrix(sheet.columns, sheet.rows);
    const ws = XLSX.utils.aoa_to_sheet([headers, ...data]);
    XLSX.utils.book_append_sheet(wb, ws, (sheet.name || 'Sheet').slice(0, 31));
  }
  XLSX.writeFile(wb, `${filename}.xlsx`);
}

export function downloadPdf({ columns, rows, filename = 'export', title = 'Export' }) {
  const { headers, data } = rowsToMatrix(columns, rows);
  const doc = new jsPDF({ orientation: headers.length > 5 ? 'landscape' : 'portrait' });
  doc.setFontSize(14);
  doc.text(String(title), 14, 16);
  doc.setFontSize(9);
  doc.setTextColor(100);
  doc.text(`Generated ${new Date().toLocaleString('en-IN')} · ${rows.length} rows`, 14, 22);
  autoTable(doc, {
    head: [headers],
    body: data.map((r) => r.map((c) => String(c ?? ''))),
    startY: 26,
    styles: { fontSize: 8, cellPadding: 2 },
    headStyles: { fillColor: [124, 108, 255] },
  });
  doc.save(`${filename}.pdf`);
}

/** Filter rows by month/year using a date field or getter */
export function filterByMonthYear(rows, { month, year, dateKey, getDate }) {
  if (!month && !year) return rows;
  return rows.filter((row) => {
    let d;
    if (getDate) d = getDate(row);
    else if (dateKey) d = row[dateKey];
    else return true;
    if (!d) return false;
    // Prefer YYYY-MM-DD to avoid timezone day-shifts
    const m = String(d).match(/^(\d{4})-(\d{2})/);
    if (m) {
      const y = Number(m[1]);
      const mo = Number(m[2]);
      if (year && y !== Number(year)) return false;
      if (month && mo !== Number(month)) return false;
      return true;
    }
    const dt = new Date(d);
    if (Number.isNaN(dt.getTime())) return false;
    if (year && dt.getFullYear() !== Number(year)) return false;
    if (month && dt.getMonth() + 1 !== Number(month)) return false;
    return true;
  });
}

export function filterByMonthYearFields(rows, { month, year, monthKey = 'month', yearKey = 'year' }) {
  return rows.filter((row) => {
    if (year && Number(row[yearKey]) !== Number(year)) return false;
    if (month && Number(row[monthKey]) !== Number(month)) return false;
    return true;
  });
}
