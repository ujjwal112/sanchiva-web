import { useCallback, useEffect, useMemo, useState } from 'react';
import { api, formatCurrency, formatDate, todayISO, MONTHS } from '../api';
import { Tabs, CategorySelect, DataTable, DateInput, useToast } from '../components/ui';
import { PieChart, categoryChartData } from '../components/Charts';
import { downloadExcel, downloadExcelMulti, downloadPdf } from '../utils/export';

const emptyForm = {
  category: '',
  custom_category: '',
  amount: '',
  expense_date: todayISO(),
  item_name: '',
};

const expenseExportCols = [
  { key: 'expense_date', label: 'Date', export: (r) => String(r.expense_date).slice(0, 10) },
  { key: 'item_name', label: 'Item' },
  { key: 'category', label: 'Category' },
  { key: 'amount', label: 'Amount', export: (r) => Number(r.amount) },
];

export default function DailyExpense() {
  const [mainTab, setMainTab] = useState('entry');
  const [form, setForm] = useState(emptyForm);
  const [editingId, setEditingId] = useState(null);
  const [list, setList] = useState([]);
  const [weeks, setWeeks] = useState([]);
  const [months, setMonths] = useState([]);
  const [year, setYear] = useState(new Date().getFullYear());
  const [month, setMonth] = useState(new Date().getMonth() + 1);
  const [weekSlide, setWeekSlide] = useState(0);
  const [exportFormat, setExportFormat] = useState('excel'); // excel | pdf
  const { show, Toast } = useToast();

  const loadList = useCallback(() => {
    api.get('/expenses').then(setList).catch((e) => show(e.message, 'error'));
  }, []);

  const loadSummaries = useCallback(() => {
    api
      .get(`/expenses/summary/weeks?year=${year}&month=${month}`)
      .then((data) => {
        setWeeks(data);
        setWeekSlide(0);
      })
      .catch((e) => show(e.message, 'error'));
    api
      .get(`/expenses/summary/months?year=${year}`)
      .then(setMonths)
      .catch((e) => show(e.message, 'error'));
  }, [year, month]);

  useEffect(() => {
    loadList();
  }, [loadList]);

  useEffect(() => {
    if (mainTab === 'data') loadSummaries();
  }, [mainTab, loadSummaries]);

  const set = (k, v) => setForm((f) => ({ ...f, [k]: v }));

  const reset = () => {
    setForm(emptyForm);
    setEditingId(null);
  };

  const submit = async (e) => {
    e.preventDefault();
    try {
      const payload = {
        category: form.category,
        custom_category: form.custom_category,
        amount: Number(form.amount),
        expense_date: form.expense_date,
        item_name: form.item_name,
      };
      if (editingId) {
        await api.put(`/expenses/${editingId}`, payload);
        show('Expense updated');
      } else {
        await api.post('/expenses', payload);
        show('Expense added');
      }
      reset();
      loadList();
      if (mainTab === 'data') loadSummaries();
    } catch (err) {
      show(err.message, 'error');
    }
  };

  const onEdit = (row) => {
    setEditingId(row.id);
    setForm({
      category: row.category,
      custom_category: '',
      amount: row.amount,
      expense_date: String(row.expense_date).slice(0, 10),
      item_name: row.item_name,
    });
    setMainTab('entry');
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const onDelete = async (row) => {
    if (!confirm('Delete this expense?')) return;
    try {
      await api.del(`/expenses/${row.id}`);
      show('Deleted');
      loadList();
      if (mainTab === 'data') loadSummaries();
    } catch (err) {
      show(err.message, 'error');
    }
  };

  const columns = [
    {
      key: 'expense_date',
      label: 'Date',
      render: (r) => formatDate(r.expense_date),
      export: (r) => String(r.expense_date).slice(0, 10),
    },
    { key: 'item_name', label: 'Item' },
    {
      key: 'category',
      label: 'Category',
      render: (r) => <span className="badge">{r.category}</span>,
      export: (r) => r.category,
    },
    {
      key: 'amount',
      label: 'Amount',
      render: (r) => formatCurrency(r.amount),
      export: (r) => Number(r.amount),
    },
  ];

  const currentMonthCard = useMemo(
    () => months.find((m) => m.month === month) || { month, year, total: 0, byCategory: {}, expenses: [] },
    [months, month, year]
  );

  // Weeks already filtered by API month; keep client safety filter
  const monthWeeks = useMemo(() => {
    if (!weeks?.length) return [];
    return weeks.filter((w) => {
      if (w.expenses?.some((e) => {
        const d = String(e.expense_date).slice(0, 10);
        const [y, m] = d.split('-').map(Number);
        return y === year && m === month;
      })) return true;
      const start = new Date(w.weekStart);
      const end = new Date(w.weekEnd);
      const ms = new Date(year, month - 1, 1);
      const me = new Date(year, month, 0, 23, 59, 59);
      return start <= me && end >= ms;
    });
  }, [weeks, month, year]);

  const maxSlide = Math.max(0, monthWeeks.length - 2);
  const visibleWeeks = monthWeeks.slice(weekSlide, weekSlide + 2);

  const getMonthRows = () =>
    currentMonthCard.expenses ||
    list.filter((r) => {
      const d = String(r.expense_date).slice(0, 10);
      const [y, m] = d.split('-').map(Number);
      return y === year && m === month;
    });

  const getYearRows = () =>
    list.filter((r) => Number(String(r.expense_date).slice(0, 4)) === year);

  const getMonthSummary = () => {
    const monthSummaryCols = [
      { key: 'month', label: 'Month' },
      { key: 'total', label: 'Total' },
      { key: 'categories', label: 'Categories breakdown' },
    ];
    const monthSummaryRows = months.map((m) => ({
      month: `${MONTHS[m.month - 1]} ${m.year}`,
      total: Number(m.total),
      categories: Object.entries(m.byCategory || {})
        .map(([k, v]) => `${k}: ${v}`)
        .join('; '),
    }));
    return { monthSummaryCols, monthSummaryRows };
  };

  const downloadSelectedMonth = (format) => {
    const monthRows = getMonthRows();
    const allYearRows = getYearRows();
    const { monthSummaryCols, monthSummaryRows } = getMonthSummary();
    const fname = `daily_expenses_${year}_${String(month).padStart(2, '0')}`;
    const title = `Daily Expenses · ${MONTHS[month - 1]} ${year}`;

    if (!monthRows.length && !allYearRows.length) {
      show('No data to download for this period', 'error');
      return;
    }

    if (format === 'pdf') {
      if (!monthRows.length) {
        show('No expenses for the selected month', 'error');
        return;
      }
      downloadPdf({
        columns: expenseExportCols,
        rows: monthRows,
        filename: `${fname}_month`,
        title,
      });
      show('PDF downloaded');
      return;
    }

    downloadExcelMulti({
      filename: fname,
      sheets: [
        {
          name: `${MONTHS[month - 1]} ${year}`,
          columns: expenseExportCols,
          rows: monthRows,
        },
        {
          name: `All ${year} entries`,
          columns: expenseExportCols,
          rows: allYearRows,
        },
        {
          name: `${year} month totals`,
          columns: monthSummaryCols,
          rows: monthSummaryRows,
        },
      ],
    });
    show('Excel downloaded');
  };

  const downloadAllMonths = (format) => {
    const allYearRows = getYearRows();
    const fname = `daily_expenses_${year}_all_months`;
    const title = `Daily Expenses · All months ${year}`;

    if (!allYearRows.length) {
      show('No data to download for this year', 'error');
      return;
    }

    if (format === 'pdf') {
      downloadPdf({
        columns: expenseExportCols,
        rows: allYearRows,
        filename: fname,
        title,
      });
      show('PDF downloaded');
      return;
    }

    const sheets = [
      {
        name: `All ${year}`,
        columns: expenseExportCols,
        rows: allYearRows,
      },
    ];
    for (const m of months) {
      sheets.push({
        name: MONTHS[m.month - 1].slice(0, 3),
        columns: expenseExportCols,
        rows: m.expenses || [],
      });
    }
    if (!months.length) {
      downloadExcel({
        columns: expenseExportCols,
        rows: allYearRows,
        filename: fname,
        sheetName: String(year),
      });
    } else {
      downloadExcelMulti({ filename: fname, sheets });
    }
    show('Excel downloaded');
  };

  return (
    <div>
      {Toast}
      <Tabs
        tabs={[
          { id: 'entry', label: 'Daily Expense Entry' },
          { id: 'data', label: 'Daily Expense Data' },
        ]}
        active={mainTab}
        onChange={setMainTab}
      />

      {mainTab === 'entry' && (
        <>
          <div className="card">
            <h3>{editingId ? 'Edit expense' : 'Add daily expense'}</h3>
            <form onSubmit={submit} style={{ marginTop: '1rem' }}>
              <div className="form-grid">
                <CategorySelect
                  section="expense"
                  value={form.category}
                  onChange={(v) => set('category', v)}
                  customValue={form.custom_category}
                  onCustomChange={(v) => set('custom_category', v)}
                />
                <div className="field">
                  <label>Amount (₹)</label>
                  <input
                    type="number"
                    min="0"
                    step="0.01"
                    required
                    value={form.amount}
                    onChange={(e) => set('amount', e.target.value)}
                  />
                </div>
                <div className="field field-date">
                  <label>Date</label>
                  <DateInput
                    required
                    value={form.expense_date}
                    onChange={(e) => set('expense_date', e.target.value)}
                  />
                </div>
                <div className="field">
                  <label>Item name</label>
                  <input
                    required
                    value={form.item_name}
                    onChange={(e) => set('item_name', e.target.value)}
                    placeholder="e.g. Milk, Uber, Amazon order"
                  />
                </div>
              </div>
              <div className="form-actions">
                <button className="btn btn-primary" type="submit">
                  {editingId ? 'Update' : 'Add expense'}
                </button>
                {editingId && (
                  <button type="button" className="btn btn-ghost" onClick={reset}>
                    Cancel edit
                  </button>
                )}
              </div>
            </form>
          </div>

          <div className="card live-list">
            <h4>Live entries · 10 most recent per page</h4>
            <DataTable
              columns={columns}
              rows={list}
              onEdit={onEdit}
              onDelete={onDelete}
              title="Daily Expenses"
              exportFilename="daily_expenses"
              filterMode="date"
              dateKey="expense_date"
            />
          </div>
        </>
      )}

      {mainTab === 'data' && (
        <>
          <div className="card data-filter-bar">
            <div className="data-filter-bar__head">
              <div>
                <h3>Month & week overview</h3>
                <p className="muted">Pick a period, then download as Excel or PDF for that month or the full year</p>
              </div>
            </div>

            <div className="data-filter-bar__body">
              <div className="data-filter-bar__period">
                <span className="data-filter-bar__actions-label">Period</span>
                <div className="data-filter-bar__period-stack">
                  <div className="data-filter-bar__period-chip">
                    <span className="muted">Viewing</span>
                    <strong>
                      {MONTHS[month - 1]} {year}
                    </strong>
                  </div>
                  <div className="data-filter-bar__filters">
                    <div className="field">
                      <label>Month</label>
                      <select value={month} onChange={(e) => setMonth(Number(e.target.value))}>
                        {MONTHS.map((m, i) => (
                          <option key={m} value={i + 1}>
                            {m}
                          </option>
                        ))}
                      </select>
                    </div>
                    <div className="field">
                      <label>Year</label>
                      <select value={year} onChange={(e) => setYear(Number(e.target.value))}>
                        {Array.from({ length: 7 }, (_, i) => new Date().getFullYear() - i).map((y) => (
                          <option key={y} value={y}>
                            {y}
                          </option>
                        ))}
                      </select>
                    </div>
                  </div>
                </div>
              </div>

              <div className="data-filter-bar__actions">
                <span className="data-filter-bar__actions-label">Download</span>
                <div className="data-filter-bar__download-stack">
                  <div className="field data-filter-bar__format">
                    <label>File type</label>
                    <select
                      value={exportFormat}
                      onChange={(e) => setExportFormat(e.target.value)}
                      aria-label="Download file type"
                    >
                      <option value="excel">Excel (.xlsx)</option>
                      <option value="pdf">PDF (.pdf)</option>
                    </select>
                  </div>
                  <div className="data-filter-bar__btns">
                    <button
                      type="button"
                      className="btn btn-primary"
                      onClick={() => downloadSelectedMonth(exportFormat)}
                    >
                      Selected month
                      <span className="btn-sub">
                        {MONTHS[month - 1]} {year} · {exportFormat === 'pdf' ? 'PDF' : 'Excel'}
                      </span>
                    </button>
                    <button
                      type="button"
                      className="btn btn-ghost"
                      onClick={() => downloadAllMonths(exportFormat)}
                    >
                      All months
                      <span className="btn-sub">
                        Full year {year} · {exportFormat === 'pdf' ? 'PDF' : 'Excel'}
                      </span>
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Single selected month card only */}
          <div className="card" style={{ marginBottom: '1.1rem' }}>
            <div>
              <h3>
                {MONTHS[month - 1]} {year}
              </h3>
              <p className="muted">Category-wise spend for the selected month</p>
              <div className="metric">{formatCurrency(currentMonthCard?.total || 0)}</div>
            </div>
            <PieChart {...categoryChartData(currentMonthCard?.byCategory || {})} doughnut />
          </div>

          {/* Weekly slider — current month only, 2 cards at a time */}
          <div className="week-slider-section">
            <div className="flex-between" style={{ marginBottom: '0.85rem' }}>
              <div>
                <h3 style={{ fontWeight: 600 }}>Weeks · {MONTHS[month - 1]} {year}</h3>
                <p className="muted">Sunday → Saturday · slide to see more (2 at a time)</p>
              </div>
              <div className="slider-controls">
                <button
                  type="button"
                  className="btn btn-ghost btn-sm slider-arrow"
                  disabled={weekSlide <= 0}
                  onClick={() => setWeekSlide((s) => Math.max(0, s - 1))}
                  aria-label="Previous weeks"
                >
                  ←
                </button>
                <span className="muted slider-pos">
                  {monthWeeks.length
                    ? `${weekSlide + 1}–${Math.min(weekSlide + 2, monthWeeks.length)} / ${monthWeeks.length}`
                    : '0'}
                </span>
                <button
                  type="button"
                  className="btn btn-ghost btn-sm slider-arrow"
                  disabled={weekSlide >= maxSlide}
                  onClick={() => setWeekSlide((s) => Math.min(maxSlide, s + 1))}
                  aria-label="Next weeks"
                >
                  →
                </button>
              </div>
            </div>

            {!monthWeeks.length ? (
              <div className="card empty">
                <span className="emoji">📅</span>
                No weekly data for {MONTHS[month - 1]} {year}
              </div>
            ) : (
              <>
                <div className="week-slider-track">
                  {visibleWeeks.map((w) => {
                    const pie = categoryChartData(w.byCategory);
                    return (
                      <div className="card week-card" key={w.weekStart}>
                        <h3>
                          {formatDate(w.weekStart)} – {formatDate(w.weekEnd)}
                        </h3>
                        <p className="muted">
                          Total {formatCurrency(w.total)} · {w.expenses.length} items
                        </p>
                        <div className="week-chart-sm">
                          <PieChart labels={pie.labels} values={pie.values} doughnut />
                        </div>
                        <div className="week-lines">
                          {w.expenses.map((e) => (
                            <div className="week-line" key={e.id}>
                              <span className="wl-date">{formatDate(e.expense_date)}</span>
                              <span className="wl-item" title={e.item_name}>
                                {e.item_name}
                              </span>
                              <span className="badge wl-cat">{e.category}</span>
                              <span className="wl-amt">{formatCurrency(e.amount)}</span>
                              <span className="row-actions">
                                <button
                                  className="btn btn-ghost btn-sm"
                                  type="button"
                                  onClick={() => onEdit(e)}
                                >
                                  Edit
                                </button>
                                <button
                                  className="btn btn-danger btn-sm"
                                  type="button"
                                  onClick={() => onDelete(e)}
                                >
                                  Del
                                </button>
                              </span>
                            </div>
                          ))}
                          {!w.expenses.length && <p className="muted">No entries</p>}
                        </div>
                      </div>
                    );
                  })}
                </div>

                {monthWeeks.length > 2 && (
                  <input
                    type="range"
                    className="week-range"
                    min={0}
                    max={maxSlide}
                    value={weekSlide}
                    onChange={(e) => setWeekSlide(Number(e.target.value))}
                    aria-label="Slide weeks"
                  />
                )}
              </>
            )}
          </div>

          <div className="card live-list">
            <h4>All expenses · paginated (edit / delete)</h4>
            <DataTable
              columns={columns}
              rows={list}
              onEdit={onEdit}
              onDelete={onDelete}
              title="Daily Expenses"
              exportFilename="daily_expenses"
              filterMode="date"
              dateKey="expense_date"
            />
          </div>
        </>
      )}
    </div>
  );
}
