import { forwardRef, useEffect, useMemo, useState } from 'react';
import { api } from '../api';
import { downloadExcel, downloadPdf, filterByMonthYear, filterByMonthYearFields } from '../utils/export';

export function Tabs({ tabs, active, onChange }) {
  return (
    <div className="tabs">
      {tabs.map((t) => (
        <button
          key={t.id}
          type="button"
          className={`tab ${active === t.id ? 'active' : ''}`}
          onClick={() => onChange(t.id)}
        >
          {t.label}
        </button>
      ))}
    </div>
  );
}

/**
 * Date input: clicking anywhere on the textbox opens the calendar
 * (not only the native calendar icon).
 */
export const DateInput = forwardRef(function DateInput({ className = '', onClick, ...props }, ref) {
  return (
    <input
      ref={ref}
      type="date"
      className={`date-input-clickable ${className}`.trim()}
      onClick={(e) => {
        try {
          e.currentTarget.showPicker?.();
        } catch {
          /* unsupported or already open */
        }
        onClick?.(e);
      }}
      {...props}
    />
  );
});

/**
 * Password field with show/hide (peek) toggle.
 */
export const PasswordInput = forwardRef(function PasswordInput(
  { className = '', id, ...props },
  ref
) {
  const [visible, setVisible] = useState(false);
  return (
    <div className="password-input-wrap">
      <input
        ref={ref}
        id={id}
        type={visible ? 'text' : 'password'}
        className={`password-input-field ${className}`.trim()}
        {...props}
      />
      <button
        type="button"
        className="password-peek-btn"
        onClick={() => setVisible((v) => !v)}
        aria-label={visible ? 'Hide password' : 'Show password'}
        title={visible ? 'Hide password' : 'Show password'}
      >
        {visible ? (
          /* eye-off */
          <svg className="password-peek-icon" viewBox="0 0 24 24" width="18" height="18" aria-hidden>
            <path
              fill="currentColor"
              d="M3.28 2.22 2.22 3.28l3.12 3.12A11.6 11.6 0 0 0 1 12c1.73 4.04 5.78 7 11 7 1.8 0 3.5-.36 5.04-1.02l3.68 3.68 1.06-1.06L3.28 2.22ZM12 17c-3.84 0-7.05-2.24-8.52-5 .53-1.18 1.35-2.24 2.38-3.1l1.64 1.64A4 4 0 0 0 12 16c.55 0 1.07-.11 1.54-.31l1.48 1.48A8.8 8.8 0 0 1 12 17Zm0-10a4 4 0 0 1 4 4c0 .45-.08.88-.22 1.28l1.54 1.54c.9-.92 1.58-2.05 1.98-3.32C17.8 7.24 15.1 5 12 5c-.95 0-1.86.18-2.7.5l1.48 1.48c.38-.12.79-.18 1.22-.18Z"
            />
          </svg>
        ) : (
          /* eye */
          <svg className="password-peek-icon" viewBox="0 0 24 24" width="18" height="18" aria-hidden>
            <path
              fill="currentColor"
              d="M12 5c-5.22 0-9.27 2.96-11 7 1.73 4.04 5.78 7 11 7s9.27-2.96 11-7c-1.73-4.04-5.78-7-11-7Zm0 12a5 5 0 1 1 0-10 5 5 0 0 1 0 10Zm0-2a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z"
            />
          </svg>
        )}
      </button>
    </div>
  );
});

export function CategorySelect({ section, value, onChange, customValue, onCustomChange }) {
  const [cats, setCats] = useState([]);

  const load = () => {
    api.get(`/categories/${section}`).then((d) => setCats(d.categories || [])).catch(() => {});
  };

  useEffect(() => {
    load();
  }, [section]);

  useEffect(() => {
    if (value && value !== 'Other' && !cats.includes(value)) load();
  }, [value]);

  return (
    <>
      <div className="field">
        <label>Category / Type</label>
        <select value={value} onChange={(e) => onChange(e.target.value)}>
          <option value="">Select…</option>
          {cats.map((c) => (
            <option key={c} value={c}>
              {c}
            </option>
          ))}
        </select>
      </div>
      {value === 'Other' && (
        <div className="field">
          <label>Custom name (saved for you)</label>
          <input
            value={customValue || ''}
            onChange={(e) => onCustomChange(e.target.value)}
            placeholder="Enter custom category"
          />
        </div>
      )}
    </>
  );
}

/**
 * Paginated data table (10 rows) with Excel/PDF download.
 *
 * filterMode:
 *  - 'none'  : download all only
 *  - 'date'  : filter by date field (dateKey)
 *  - 'period': filter by monthKey/yearKey on row
 */
export function DataTable({
  columns,
  rows = [],
  onEdit,
  onDelete,
  rowKey = 'id',
  pageSize = 10,
  title = 'Entries',
  exportFilename = 'export',
  filterMode = 'none',
  dateKey = null,
  getDate = null,
  monthKey = 'month',
  yearKey = 'year',
  showDownload = true,
}) {
  const [page, setPage] = useState(1);
  const [dlScope, setDlScope] = useState('all'); // all | filtered
  const [dlMonth, setDlMonth] = useState(new Date().getMonth() + 1);
  const [dlYear, setDlYear] = useState(new Date().getFullYear());
  const [dlFormat, setDlFormat] = useState('excel'); // excel | pdf
  const [showDlPanel, setShowDlPanel] = useState(false);

  // reset page when data shrinks
  useEffect(() => {
    setPage(1);
  }, [rows?.length, pageSize]);

  const total = rows?.length || 0;
  const totalPages = Math.max(1, Math.ceil(total / pageSize));
  const safePage = Math.min(page, totalPages);

  const pageRows = useMemo(() => {
    const start = (safePage - 1) * pageSize;
    return (rows || []).slice(start, start + pageSize);
  }, [rows, safePage, pageSize]);

  const years = useMemo(() => {
    const cy = new Date().getFullYear();
    const list = [];
    for (let y = cy; y >= cy - 8; y--) list.push(y);
    return list;
  }, []);

  const getFiltered = () => {
    if (dlScope === 'all' || filterMode === 'none') return rows || [];
    if (filterMode === 'date') {
      return filterByMonthYear(rows || [], {
        month: dlMonth,
        year: dlYear,
        dateKey,
        getDate,
      });
    }
    if (filterMode === 'period') {
      return filterByMonthYearFields(rows || [], {
        month: dlMonth,
        year: dlYear,
        monthKey,
        yearKey,
      });
    }
    return rows || [];
  };

  const handleDownload = () => {
    const data = getFiltered();
    const exportCols = columns.map((c) => ({
      key: c.key,
      label: c.label,
      export: c.export || ((row) => (c.render ? stripRender(c, row) : row[c.key])),
    }));
    const fname =
      dlScope === 'filtered' && filterMode !== 'none'
        ? `${exportFilename}_${dlYear}_${String(dlMonth).padStart(2, '0')}`
        : `${exportFilename}_all`;
    const label =
      dlScope === 'filtered' && filterMode !== 'none'
        ? `${title} (${dlMonth}/${dlYear})`
        : `${title} (All)`;

    if (!data.length) {
      alert('No rows to download for the selected filter.');
      return;
    }
    if (dlFormat === 'pdf') {
      downloadPdf({ columns: exportCols, rows: data, filename: fname, title: label });
    } else {
      downloadExcel({ columns: exportCols, rows: data, filename: fname, sheetName: title });
    }
    setShowDlPanel(false);
  };

  if (!rows?.length) {
    return (
      <div className="empty">
        <span className="emoji">📭</span>
        No entries yet. Add one above.
      </div>
    );
  }

  return (
    <div className="data-table-block">
      {showDownload && (
        <div className="list-toolbar">
          <span className="muted list-count">
            Showing {(safePage - 1) * pageSize + 1}–{Math.min(safePage * pageSize, total)} of {total}
          </span>
          <button type="button" className="btn btn-ghost btn-sm" onClick={() => setShowDlPanel((v) => !v)}>
            ⬇ Download
          </button>
        </div>
      )}

      {showDlPanel && (
        <div className="download-panel card">
          <h4>Download list</h4>
          <div className="form-grid" style={{ marginTop: '0.75rem' }}>
            {filterMode !== 'none' && (
              <>
                <div className="field">
                  <label>Scope</label>
                  <select value={dlScope} onChange={(e) => setDlScope(e.target.value)}>
                    <option value="all">All data</option>
                    <option value="filtered">Filter by month & year</option>
                  </select>
                </div>
                {dlScope === 'filtered' && (
                  <>
                    <div className="field">
                      <label>Month</label>
                      <select value={dlMonth} onChange={(e) => setDlMonth(Number(e.target.value))}>
                        {Array.from({ length: 12 }, (_, i) => (
                          <option key={i + 1} value={i + 1}>
                            {new Date(2000, i, 1).toLocaleString('en', { month: 'long' })}
                          </option>
                        ))}
                      </select>
                    </div>
                    <div className="field">
                      <label>Year</label>
                      <select value={dlYear} onChange={(e) => setDlYear(Number(e.target.value))}>
                        {years.map((y) => (
                          <option key={y} value={y}>
                            {y}
                          </option>
                        ))}
                      </select>
                    </div>
                  </>
                )}
              </>
            )}
            <div className="field">
              <label>File type</label>
              <select value={dlFormat} onChange={(e) => setDlFormat(e.target.value)}>
                <option value="excel">Excel (.xlsx)</option>
                <option value="pdf">PDF (.pdf)</option>
              </select>
            </div>
          </div>
          <div className="form-actions" style={{ marginTop: '0.75rem' }}>
            <button type="button" className="btn btn-primary btn-sm" onClick={handleDownload}>
              Download {dlFormat === 'pdf' ? 'PDF' : 'Excel'}
            </button>
            <button type="button" className="btn btn-ghost btn-sm" onClick={() => setShowDlPanel(false)}>
              Cancel
            </button>
          </div>
        </div>
      )}

      <div className="table-wrap">
        <table className="data-table">
          <thead>
            <tr>
              {columns.map((c) => (
                <th key={c.key}>{c.label}</th>
              ))}
              {(onEdit || onDelete) && <th>Actions</th>}
            </tr>
          </thead>
          <tbody>
            {pageRows.map((row) => (
              <tr key={row[rowKey]}>
                {columns.map((c) => (
                  <td key={c.key}>{c.render ? c.render(row) : row[c.key]}</td>
                ))}
                {(onEdit || onDelete) && (
                  <td>
                    <div className="row-actions">
                      {onEdit && (
                        <button type="button" className="btn btn-ghost btn-sm" onClick={() => onEdit(row)}>
                          Edit
                        </button>
                      )}
                      {onDelete && (
                        <button type="button" className="btn btn-danger btn-sm" onClick={() => onDelete(row)}>
                          Delete
                        </button>
                      )}
                    </div>
                  </td>
                )}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {totalPages > 1 && (
        <div className="pagination">
          <button
            type="button"
            className="btn btn-ghost btn-sm"
            disabled={safePage <= 1}
            onClick={() => setPage((p) => Math.max(1, p - 1))}
          >
            ← Prev
          </button>
          <div className="page-numbers">
            {buildPageList(safePage, totalPages).map((p, i) =>
              p === '…' ? (
                <span key={`e${i}`} className="page-ellipsis">
                  …
                </span>
              ) : (
                <button
                  key={p}
                  type="button"
                  className={`page-btn ${p === safePage ? 'active' : ''}`}
                  onClick={() => setPage(p)}
                >
                  {p}
                </button>
              )
            )}
          </div>
          <button
            type="button"
            className="btn btn-ghost btn-sm"
            disabled={safePage >= totalPages}
            onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
          >
            Next →
          </button>
        </div>
      )}
    </div>
  );
}

function stripRender(col, row) {
  if (col.export) return col.export(row);
  const v = row[col.key];
  return v == null ? '' : v;
}

function buildPageList(current, total) {
  if (total <= 7) return Array.from({ length: total }, (_, i) => i + 1);
  const pages = new Set([1, total, current, current - 1, current + 1]);
  const sorted = [...pages].filter((p) => p >= 1 && p <= total).sort((a, b) => a - b);
  const out = [];
  for (let i = 0; i < sorted.length; i++) {
    if (i > 0 && sorted[i] - sorted[i - 1] > 1) out.push('…');
    out.push(sorted[i]);
  }
  return out;
}

export function useToast() {
  const [toast, setToast] = useState(null);
  const show = (message, type = 'ok') => {
    setToast({ message, type });
    setTimeout(() => setToast(null), 2800);
  };
  const Toast = toast ? (
    <div className={`toast ${toast.type === 'error' ? 'error' : ''}`}>{toast.message}</div>
  ) : null;
  return { show, Toast };
}

export function MonthYearFilters({ month, year, onMonth, onYear }) {
  const years = [];
  const cy = new Date().getFullYear();
  for (let y = cy; y >= cy - 6; y--) years.push(y);
  return (
    <div className="filters">
      <div className="field">
        <label>Month</label>
        <select value={month} onChange={(e) => onMonth(Number(e.target.value))}>
          {Array.from({ length: 12 }, (_, i) => (
            <option key={i + 1} value={i + 1}>
              {new Date(2000, i, 1).toLocaleString('en', { month: 'long' })}
            </option>
          ))}
        </select>
      </div>
      <div className="field">
        <label>Year</label>
        <select value={year} onChange={(e) => onYear(Number(e.target.value))}>
          {years.map((y) => (
            <option key={y} value={y}>
              {y}
            </option>
          ))}
        </select>
      </div>
    </div>
  );
}
