import { useCallback, useEffect, useState } from 'react';
import { api, formatCurrency, formatDate, todayISO, MONTHS } from '../api';
import { Tabs, CategorySelect, DataTable, useToast } from '../components/ui';
import { PieChart, BarChart, MultiBarChart, categoryChartData } from '../components/Charts';

const emptyLoan = {
  bank_name: '',
  emi_deduction_bank: '',
  emi_deduction_date: 5,
  emi_close_month: 12,
  emi_close_year: new Date().getFullYear() + 2,
  emi_amount: '',
  status: 'ongoing',
  start_month: new Date().getMonth() + 1,
  start_year: new Date().getFullYear(),
};

const emptySpend = {
  spend_date: todayISO(),
  spend_type: '',
  custom_type: '',
  credit_card_name: '',
  amount: '',
};

const emptyEmi = {
  emi_name: '',
  credit_card_name: '',
  start_month: new Date().getMonth() + 1,
  start_year: new Date().getFullYear(),
  end_month: 12,
  end_year: new Date().getFullYear() + 1,
  amount: '',
};

export default function LoansCredit() {
  const [topTab, setTopTab] = useState('loans');
  const [loanTab, setLoanTab] = useState('entry');
  const [ccTab, setCcTab] = useState('spends');
  const [spendTab, setSpendTab] = useState('entry');
  const [emiTab, setEmiTab] = useState('entry');

  const [loanForm, setLoanForm] = useState(emptyLoan);
  const [loanEdit, setLoanEdit] = useState(null);
  const [loans, setLoans] = useState([]);
  const [loanSummary, setLoanSummary] = useState(null);

  const [spendForm, setSpendForm] = useState(emptySpend);
  const [spendEdit, setSpendEdit] = useState(null);
  const [spends, setSpends] = useState([]);
  const [spendSummary, setSpendSummary] = useState(null);

  const [emiForm, setEmiForm] = useState(emptyEmi);
  const [emiEdit, setEmiEdit] = useState(null);
  const [emis, setEmis] = useState([]);
  const [emiSummary, setEmiSummary] = useState(null);

  const { show, Toast } = useToast();

  const loadLoans = useCallback(() => {
    api.get('/loans').then(setLoans).catch((e) => show(e.message, 'error'));
    api.get('/loans/summary').then(setLoanSummary).catch(() => {});
  }, []);

  const loadSpends = useCallback(() => {
    api.get('/credit-cards/spends').then(setSpends).catch((e) => show(e.message, 'error'));
    api.get('/credit-cards/spends/summary').then(setSpendSummary).catch(() => {});
  }, []);

  const loadEmis = useCallback(() => {
    api.get('/credit-cards/emis').then(setEmis).catch((e) => show(e.message, 'error'));
    api.get('/credit-cards/emis/summary').then(setEmiSummary).catch(() => {});
  }, []);

  useEffect(() => {
    loadLoans();
    loadSpends();
    loadEmis();
  }, [loadLoans, loadSpends, loadEmis]);

  /* ---- Loans ---- */
  const submitLoan = async (e) => {
    e.preventDefault();
    try {
      const payload = {
        ...loanForm,
        emi_amount: Number(loanForm.emi_amount),
        emi_deduction_date: Number(loanForm.emi_deduction_date),
        emi_close_month: Number(loanForm.emi_close_month),
        emi_close_year: Number(loanForm.emi_close_year),
        start_month: Number(loanForm.start_month),
        start_year: Number(loanForm.start_year),
      };
      if (loanEdit) {
        await api.put(`/loans/${loanEdit}`, payload);
        show('Loan updated');
      } else {
        await api.post('/loans', payload);
        show('Loan added');
      }
      setLoanForm(emptyLoan);
      setLoanEdit(null);
      loadLoans();
    } catch (err) {
      show(err.message, 'error');
    }
  };

  const editLoan = (row) => {
    setLoanEdit(row.id);
    setLoanForm({
      bank_name: row.bank_name,
      emi_deduction_bank: row.emi_deduction_bank,
      emi_deduction_date: row.emi_deduction_date,
      emi_close_month: row.emi_close_month,
      emi_close_year: row.emi_close_year,
      emi_amount: row.emi_amount,
      status: row.status,
      start_month: row.start_month,
      start_year: row.start_year,
    });
    setLoanTab('entry');
    setTopTab('loans');
  };

  const deleteLoan = async (row) => {
    if (!confirm('Delete this loan?')) return;
    await api.del(`/loans/${row.id}`);
    show('Loan deleted');
    loadLoans();
  };

  /* ---- CC Spends ---- */
  const submitSpend = async (e) => {
    e.preventDefault();
    try {
      const payload = {
        spend_date: spendForm.spend_date,
        spend_type: spendForm.spend_type,
        custom_type: spendForm.custom_type,
        credit_card_name: spendForm.credit_card_name,
        amount: Number(spendForm.amount),
      };
      if (spendEdit) {
        await api.put(`/credit-cards/spends/${spendEdit}`, payload);
        show('Spend updated');
      } else {
        await api.post('/credit-cards/spends', payload);
        show('Spend added');
      }
      setSpendForm(emptySpend);
      setSpendEdit(null);
      loadSpends();
    } catch (err) {
      show(err.message, 'error');
    }
  };

  const editSpend = (row) => {
    setSpendEdit(row.id);
    setSpendForm({
      spend_date: String(row.spend_date).slice(0, 10),
      spend_type: row.spend_type,
      custom_type: '',
      credit_card_name: row.credit_card_name,
      amount: row.amount,
    });
    setSpendTab('entry');
    setCcTab('spends');
    setTopTab('credit');
  };

  const deleteSpend = async (row) => {
    if (!confirm('Delete spend?')) return;
    await api.del(`/credit-cards/spends/${row.id}`);
    show('Deleted');
    loadSpends();
  };

  /* ---- CC EMI ---- */
  const submitEmi = async (e) => {
    e.preventDefault();
    try {
      const payload = {
        ...emiForm,
        amount: Number(emiForm.amount),
        start_month: Number(emiForm.start_month),
        start_year: Number(emiForm.start_year),
        end_month: Number(emiForm.end_month),
        end_year: Number(emiForm.end_year),
      };
      if (emiEdit) {
        await api.put(`/credit-cards/emis/${emiEdit}`, payload);
        show('CC EMI updated');
      } else {
        await api.post('/credit-cards/emis', payload);
        show('CC EMI added');
      }
      setEmiForm(emptyEmi);
      setEmiEdit(null);
      loadEmis();
    } catch (err) {
      show(err.message, 'error');
    }
  };

  const editEmi = (row) => {
    setEmiEdit(row.id);
    setEmiForm({
      emi_name: row.emi_name,
      credit_card_name: row.credit_card_name,
      start_month: row.start_month,
      start_year: row.start_year,
      end_month: row.end_month,
      end_year: row.end_year,
      amount: row.amount,
    });
    setEmiTab('entry');
    setCcTab('emi');
    setTopTab('credit');
  };

  const deleteEmi = async (row) => {
    if (!confirm('Delete EMI?')) return;
    await api.del(`/credit-cards/emis/${row.id}`);
    show('Deleted');
    loadEmis();
  };

  const loanColumns = [
    { key: 'bank_name', label: 'Bank' },
    { key: 'emi_deduction_bank', label: 'EMI bank' },
    { key: 'emi_deduction_date', label: 'Deduction day' },
    {
      key: 'close',
      label: 'Close',
      render: (r) => `${MONTHS[r.emi_close_month - 1]} ${r.emi_close_year}`,
      export: (r) => `${MONTHS[r.emi_close_month - 1]} ${r.emi_close_year}`,
    },
    {
      key: 'emi_amount',
      label: 'EMI',
      render: (r) => formatCurrency(r.emi_amount),
      export: (r) => Number(r.emi_amount),
    },
    {
      key: 'status',
      label: 'Status',
      render: (r) => (
        <span className={`badge ${r.status === 'closed' ? 'success' : 'warning'}`}>{r.status}</span>
      ),
      export: (r) => r.status,
    },
    {
      key: 'progress',
      label: 'Remaining',
      render: (r) => formatCurrency(r.progress?.remaining || 0),
      export: (r) => Number(r.progress?.remaining || 0),
    },
  ];

  const spendColumns = [
    {
      key: 'spend_date',
      label: 'Date',
      render: (r) => formatDate(r.spend_date),
      export: (r) => String(r.spend_date).slice(0, 10),
    },
    {
      key: 'spend_type',
      label: 'Type',
      render: (r) => <span className="badge">{r.spend_type}</span>,
      export: (r) => r.spend_type,
    },
    { key: 'credit_card_name', label: 'Card' },
    {
      key: 'amount',
      label: 'Amount',
      render: (r) => formatCurrency(r.amount),
      export: (r) => Number(r.amount),
    },
  ];

  const emiColumns = [
    { key: 'emi_name', label: 'EMI name' },
    { key: 'credit_card_name', label: 'Card' },
    {
      key: 'period',
      label: 'Period',
      render: (r) =>
        `${MONTHS[r.start_month - 1]} ${r.start_year} → ${MONTHS[r.end_month - 1]} ${r.end_year}`,
      export: (r) =>
        `${MONTHS[r.start_month - 1]} ${r.start_year} → ${MONTHS[r.end_month - 1]} ${r.end_year}`,
    },
    {
      key: 'amount',
      label: 'Amount',
      render: (r) => formatCurrency(r.amount),
      export: (r) => Number(r.amount),
    },
  ];

  const banks = loanSummary?.bankCard?.banks || [];
  const closure = loanSummary?.closureYearCard || [];
  const monthCard = loanSummary?.monthCard;

  return (
    <div>
      {Toast}
      <Tabs
        tabs={[
          { id: 'loans', label: 'Loans' },
          { id: 'credit', label: 'Credit Card' },
        ]}
        active={topTab}
        onChange={setTopTab}
      />

      {topTab === 'loans' && (
        <>
          <Tabs
            tabs={[
              { id: 'entry', label: 'Loans Entry' },
              { id: 'data', label: 'Loan Data' },
            ]}
            active={loanTab}
            onChange={setLoanTab}
          />

          {loanTab === 'entry' && (
            <>
              <div className="card">
                <h3>{loanEdit ? 'Edit loan' : 'Add loan'}</h3>
                <form onSubmit={submitLoan} style={{ marginTop: '1rem' }}>
                  <div className="form-grid">
                    <div className="field">
                      <label>Bank name (loan from)</label>
                      <input
                        required
                        value={loanForm.bank_name}
                        onChange={(e) => setLoanForm({ ...loanForm, bank_name: e.target.value })}
                      />
                    </div>
                    <div className="field">
                      <label>EMI deduction bank name</label>
                      <input
                        required
                        value={loanForm.emi_deduction_bank}
                        onChange={(e) => setLoanForm({ ...loanForm, emi_deduction_bank: e.target.value })}
                      />
                    </div>
                    <div className="field">
                      <label>EMI deduction date (day 1–31)</label>
                      <input
                        type="number"
                        min="1"
                        max="31"
                        required
                        value={loanForm.emi_deduction_date}
                        onChange={(e) => setLoanForm({ ...loanForm, emi_deduction_date: e.target.value })}
                      />
                    </div>
                    <div className="field">
                      <label>EMI close month</label>
                      <select
                        value={loanForm.emi_close_month}
                        onChange={(e) => setLoanForm({ ...loanForm, emi_close_month: e.target.value })}
                      >
                        {MONTHS.map((m, i) => (
                          <option key={m} value={i + 1}>
                            {m}
                          </option>
                        ))}
                      </select>
                    </div>
                    <div className="field">
                      <label>EMI close year</label>
                      <input
                        type="number"
                        required
                        value={loanForm.emi_close_year}
                        onChange={(e) => setLoanForm({ ...loanForm, emi_close_year: e.target.value })}
                      />
                    </div>
                    <div className="field">
                      <label>EMI amount (₹)</label>
                      <input
                        type="number"
                        min="0"
                        required
                        value={loanForm.emi_amount}
                        onChange={(e) => setLoanForm({ ...loanForm, emi_amount: e.target.value })}
                      />
                    </div>
                    <div className="field">
                      <label>Loan status</label>
                      <select
                        value={loanForm.status}
                        onChange={(e) => setLoanForm({ ...loanForm, status: e.target.value })}
                      >
                        <option value="ongoing">Ongoing</option>
                        <option value="closed">Closed</option>
                      </select>
                    </div>
                    <div className="field">
                      <label>Start month</label>
                      <select
                        value={loanForm.start_month}
                        onChange={(e) => setLoanForm({ ...loanForm, start_month: e.target.value })}
                      >
                        {MONTHS.map((m, i) => (
                          <option key={m} value={i + 1}>
                            {m}
                          </option>
                        ))}
                      </select>
                    </div>
                    <div className="field">
                      <label>Start year</label>
                      <input
                        type="number"
                        value={loanForm.start_year}
                        onChange={(e) => setLoanForm({ ...loanForm, start_year: e.target.value })}
                      />
                    </div>
                  </div>
                  <div className="form-actions">
                    <button className="btn btn-primary" type="submit">
                      {loanEdit ? 'Update loan' : 'Add loan'}
                    </button>
                    {loanEdit && (
                      <button
                        type="button"
                        className="btn btn-ghost"
                        onClick={() => {
                          setLoanEdit(null);
                          setLoanForm(emptyLoan);
                        }}
                      >
                        Cancel
                      </button>
                    )}
                  </div>
                </form>
              </div>
              <div className="card live-list">
                <h4>Live loan entries</h4>
                <DataTable
                  columns={loanColumns}
                  rows={loans}
                  onEdit={editLoan}
                  onDelete={deleteLoan}
                  title="Loans"
                  exportFilename="loans"
                  filterMode="period"
                  monthKey="emi_close_month"
                  yearKey="emi_close_year"
                />
              </div>
            </>
          )}

          {loanTab === 'data' && (
            <>
              <div className="grid grid-3" style={{ marginBottom: '1.1rem' }}>
                <div className="card">
                  <h3>This month loan flow</h3>
                  <p className="muted">Also shown on dashboard</p>
                  <div className="stat-row">
                    <span>Total loan amount</span>
                    <strong>{formatCurrency(monthCard?.totalLoanAmount)}</strong>
                  </div>
                  <div className="stat-row">
                    <span>Deducted this month</span>
                    <strong>{formatCurrency(monthCard?.deductedThisMonth)}</strong>
                  </div>
                  <div className="stat-row">
                    <span>Remaining to deduct</span>
                    <strong>{formatCurrency(monthCard?.remainingToDeduct)}</strong>
                  </div>
                  <PieChart
                    labels={['Deducted this month', 'Remaining']}
                    values={[monthCard?.deductedThisMonth || 0, monthCard?.remainingToDeduct || 0]}
                    doughnut
                  />
                </div>
                <div className="card">
                  <h3>By deduction bank</h3>
                  <p className="muted">
                    Active {loanSummary?.bankCard?.totalActiveLoans} · EMI{' '}
                    {formatCurrency(loanSummary?.bankCard?.totalMonthlyEmi)} · Closed{' '}
                    {loanSummary?.bankCard?.closedLoansCount}
                  </p>
                  <BarChart
                    labels={banks.map((b) => b.bank)}
                    values={banks.map((b) => b.totalEmi)}
                    label="EMI"
                  />
                </div>
                <div className="card">
                  <h3>Loan closure year</h3>
                  <MultiBarChart
                    labels={closure.map((c) => String(c.year))}
                    datasets={[
                      { label: 'Closing count', values: closure.map((c) => c.closingCount) },
                      { label: 'Closed', values: closure.map((c) => c.closedCount) },
                      { label: 'Active', values: closure.map((c) => c.activeCount) },
                    ]}
                  />
                </div>
              </div>
              <div className="card">
                <h3>All loans</h3>
                <DataTable
                  columns={loanColumns}
                  rows={loans}
                  onEdit={editLoan}
                  onDelete={deleteLoan}
                  title="Loans"
                  exportFilename="loans"
                  filterMode="period"
                  monthKey="emi_close_month"
                  yearKey="emi_close_year"
                />
              </div>
            </>
          )}
        </>
      )}

      {topTab === 'credit' && (
        <>
          <Tabs
            tabs={[
              { id: 'spends', label: 'Credit Card Spends' },
              { id: 'emi', label: 'Credit Card EMI' },
            ]}
            active={ccTab}
            onChange={setCcTab}
          />

          {ccTab === 'spends' && (
            <>
              <Tabs
                tabs={[
                  { id: 'entry', label: 'Entry' },
                  { id: 'data', label: 'Data' },
                ]}
                active={spendTab}
                onChange={setSpendTab}
              />
              {spendTab === 'entry' && (
                <>
                  <div className="card">
                    <h3>{spendEdit ? 'Edit spend' : 'Add credit card spend'}</h3>
                    <form onSubmit={submitSpend} style={{ marginTop: '1rem' }}>
                      <div className="form-grid">
                        <div className="field">
                          <label>Date</label>
                          <input
                            type="date"
                            required
                            value={spendForm.spend_date}
                            onChange={(e) => setSpendForm({ ...spendForm, spend_date: e.target.value })}
                          />
                        </div>
                        <CategorySelect
                          section="spend"
                          value={spendForm.spend_type}
                          onChange={(v) => setSpendForm({ ...spendForm, spend_type: v })}
                          customValue={spendForm.custom_type}
                          onCustomChange={(v) => setSpendForm({ ...spendForm, custom_type: v })}
                        />
                        <div className="field">
                          <label>Credit card name</label>
                          <input
                            required
                            value={spendForm.credit_card_name}
                            onChange={(e) => setSpendForm({ ...spendForm, credit_card_name: e.target.value })}
                          />
                        </div>
                        <div className="field">
                          <label>Amount (₹)</label>
                          <input
                            type="number"
                            min="0"
                            required
                            value={spendForm.amount}
                            onChange={(e) => setSpendForm({ ...spendForm, amount: e.target.value })}
                          />
                        </div>
                      </div>
                      <div className="form-actions">
                        <button className="btn btn-primary" type="submit">
                          {spendEdit ? 'Update' : 'Add spend'}
                        </button>
                        {spendEdit && (
                          <button
                            type="button"
                            className="btn btn-ghost"
                            onClick={() => {
                              setSpendEdit(null);
                              setSpendForm(emptySpend);
                            }}
                          >
                            Cancel
                          </button>
                        )}
                      </div>
                    </form>
                  </div>
                  <div className="card live-list">
                    <h4>Live spends</h4>
                    <DataTable
                      columns={spendColumns}
                      rows={spends}
                      onEdit={editSpend}
                      onDelete={deleteSpend}
                      title="Credit Card Spends"
                      exportFilename="cc_spends"
                      filterMode="date"
                      dateKey="spend_date"
                    />
                  </div>
                </>
              )}
              {spendTab === 'data' && (
                <>
                  <div className="grid grid-2" style={{ marginBottom: '1.1rem' }}>
                    <div className="card">
                      <h3>By spend type</h3>
                      <p className="muted">Total {formatCurrency(spendSummary?.total)}</p>
                      <PieChart {...categoryChartData(spendSummary?.byType || [])} doughnut />
                    </div>
                    <div className="card">
                      <h3>By credit card</h3>
                      <BarChart
                        labels={(spendSummary?.byCard || []).map((c) => c.name)}
                        values={(spendSummary?.byCard || []).map((c) => c.amount)}
                      />
                    </div>
                  </div>
                  <div className="card">
                    <DataTable
                      columns={spendColumns}
                      rows={spends}
                      onEdit={editSpend}
                      onDelete={deleteSpend}
                      title="Credit Card Spends"
                      exportFilename="cc_spends"
                      filterMode="date"
                      dateKey="spend_date"
                    />
                  </div>
                </>
              )}
            </>
          )}

          {ccTab === 'emi' && (
            <>
              <Tabs
                tabs={[
                  { id: 'entry', label: 'Entry' },
                  { id: 'data', label: 'Data' },
                ]}
                active={emiTab}
                onChange={setEmiTab}
              />
              {emiTab === 'entry' && (
                <>
                  <div className="card">
                    <h3>{emiEdit ? 'Edit CC EMI' : 'Add credit card EMI'}</h3>
                    <form onSubmit={submitEmi} style={{ marginTop: '1rem' }}>
                      <div className="form-grid">
                        <div className="field">
                          <label>EMI name</label>
                          <input
                            required
                            value={emiForm.emi_name}
                            onChange={(e) => setEmiForm({ ...emiForm, emi_name: e.target.value })}
                          />
                        </div>
                        <div className="field">
                          <label>Credit card name</label>
                          <input
                            required
                            value={emiForm.credit_card_name}
                            onChange={(e) => setEmiForm({ ...emiForm, credit_card_name: e.target.value })}
                          />
                        </div>
                        <div className="field">
                          <label>Start month</label>
                          <select
                            value={emiForm.start_month}
                            onChange={(e) => setEmiForm({ ...emiForm, start_month: e.target.value })}
                          >
                            {MONTHS.map((m, i) => (
                              <option key={m} value={i + 1}>
                                {m}
                              </option>
                            ))}
                          </select>
                        </div>
                        <div className="field">
                          <label>Start year</label>
                          <input
                            type="number"
                            value={emiForm.start_year}
                            onChange={(e) => setEmiForm({ ...emiForm, start_year: e.target.value })}
                          />
                        </div>
                        <div className="field">
                          <label>End month</label>
                          <select
                            value={emiForm.end_month}
                            onChange={(e) => setEmiForm({ ...emiForm, end_month: e.target.value })}
                          >
                            {MONTHS.map((m, i) => (
                              <option key={m} value={i + 1}>
                                {m}
                              </option>
                            ))}
                          </select>
                        </div>
                        <div className="field">
                          <label>End year</label>
                          <input
                            type="number"
                            value={emiForm.end_year}
                            onChange={(e) => setEmiForm({ ...emiForm, end_year: e.target.value })}
                          />
                        </div>
                        <div className="field">
                          <label>Amount (₹)</label>
                          <input
                            type="number"
                            min="0"
                            required
                            value={emiForm.amount}
                            onChange={(e) => setEmiForm({ ...emiForm, amount: e.target.value })}
                          />
                        </div>
                      </div>
                      <div className="form-actions">
                        <button className="btn btn-primary" type="submit">
                          {emiEdit ? 'Update' : 'Add EMI'}
                        </button>
                        {emiEdit && (
                          <button
                            type="button"
                            className="btn btn-ghost"
                            onClick={() => {
                              setEmiEdit(null);
                              setEmiForm(emptyEmi);
                            }}
                          >
                            Cancel
                          </button>
                        )}
                      </div>
                    </form>
                  </div>
                  <div className="card live-list">
                    <h4>Live CC EMIs</h4>
                    <DataTable
                      columns={emiColumns}
                      rows={emis}
                      onEdit={editEmi}
                      onDelete={deleteEmi}
                      title="Credit Card EMIs"
                      exportFilename="cc_emis"
                      filterMode="period"
                      monthKey="start_month"
                      yearKey="start_year"
                    />
                  </div>
                </>
              )}
              {emiTab === 'data' && (
                <>
                  <div className="grid grid-2" style={{ marginBottom: '1.1rem' }}>
                    <div className="card">
                      <h3>Monthly EMI by card</h3>
                      <p className="muted">
                        Total monthly {formatCurrency(emiSummary?.totalMonthly)} · Overall{' '}
                        {formatCurrency(emiSummary?.totalOverall)}
                      </p>
                      <BarChart
                        labels={(emiSummary?.byCard || []).map((c) => c.name)}
                        values={(emiSummary?.byCard || []).map((c) => c.monthly)}
                        label="Monthly EMI"
                      />
                    </div>
                    <div className="card">
                      <h3>Total EMI commitment by card</h3>
                      <PieChart
                        labels={(emiSummary?.byCard || []).map((c) => c.name)}
                        values={(emiSummary?.byCard || []).map((c) => c.total)}
                        doughnut
                      />
                    </div>
                  </div>
                  <div className="card">
                    <DataTable
                      columns={emiColumns}
                      rows={emis}
                      onEdit={editEmi}
                      onDelete={deleteEmi}
                      title="Credit Card EMIs"
                      exportFilename="cc_emis"
                      filterMode="period"
                      monthKey="start_month"
                      yearKey="start_year"
                    />
                  </div>
                </>
              )}
            </>
          )}
        </>
      )}
    </div>
  );
}
