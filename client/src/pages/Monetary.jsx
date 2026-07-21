import { useCallback, useEffect, useState } from 'react';
import { api, formatCurrency, formatDate, todayISO, MONTHS } from '../api';
import { Tabs, CategorySelect, DataTable, DateInput, GlassSelect, useToast, MonthYearFilters } from '../components/ui';
import { PieChart, BarChart, categoryChartData } from '../components/Charts';

const emptyIncome = {
  source_name: '',
  amount: '',
  month: new Date().getMonth() + 1,
  year: new Date().getFullYear(),
};

const emptyAsset = { asset_type: '', custom_type: '', amount: '', notes: '' };
const emptyGiven = { person_name: '', given_date: todayISO(), amount: '', notes: '' };

export default function Monetary() {
  const [tab, setTab] = useState('income');
  const [incomeTab, setIncomeTab] = useState('entry');
  const [assetTab, setAssetTab] = useState('entry');
  const [givenTab, setGivenTab] = useState('entry');

  const [incomeForm, setIncomeForm] = useState(emptyIncome);
  const [incomeEdit, setIncomeEdit] = useState(null);
  const [incomes, setIncomes] = useState([]);
  const [incomeSummary, setIncomeSummary] = useState(null);
  const [filterMonth, setFilterMonth] = useState(new Date().getMonth() + 1);
  const [filterYear, setFilterYear] = useState(new Date().getFullYear());

  const [assetForm, setAssetForm] = useState(emptyAsset);
  const [assetEdit, setAssetEdit] = useState(null);
  const [assets, setAssets] = useState([]);
  const [assetSummary, setAssetSummary] = useState(null);

  const [givenForm, setGivenForm] = useState(emptyGiven);
  const [givenEdit, setGivenEdit] = useState(null);
  const [given, setGiven] = useState([]);
  const [givenSummary, setGivenSummary] = useState(null);

  const { show, Toast } = useToast();

  const loadIncome = useCallback(() => {
    api.get('/monetary/income').then(setIncomes).catch((e) => show(e.message, 'error'));
    api
      .get(`/monetary/income/summary?month=${filterMonth}&year=${filterYear}`)
      .then(setIncomeSummary)
      .catch(() => {});
  }, [filterMonth, filterYear]);

  const loadAssets = useCallback(() => {
    api.get('/monetary/assets').then(setAssets).catch((e) => show(e.message, 'error'));
    api.get('/monetary/assets/summary').then(setAssetSummary).catch(() => {});
  }, []);

  const loadGiven = useCallback(() => {
    api.get('/monetary/money-given').then(setGiven).catch((e) => show(e.message, 'error'));
    api.get('/monetary/money-given/summary').then(setGivenSummary).catch(() => {});
  }, []);

  useEffect(() => {
    loadIncome();
    loadAssets();
    loadGiven();
  }, [loadIncome, loadAssets, loadGiven]);

  /* Income */
  const submitIncome = async (e) => {
    e.preventDefault();
    try {
      const payload = {
        source_name: incomeForm.source_name,
        amount: Number(incomeForm.amount),
        month: Number(incomeForm.month),
        year: Number(incomeForm.year),
      };
      if (incomeEdit) {
        await api.put(`/monetary/income/${incomeEdit}`, payload);
        show('Income updated');
      } else {
        await api.post('/monetary/income', payload);
        show('Income added');
      }
      setIncomeForm(emptyIncome);
      setIncomeEdit(null);
      loadIncome();
    } catch (err) {
      show(err.message, 'error');
    }
  };

  const editIncome = (row) => {
    setIncomeEdit(row.id);
    setIncomeForm({
      source_name: row.source_name,
      amount: row.amount,
      month: row.month,
      year: row.year,
    });
    setIncomeTab('entry');
    setTab('income');
  };

  const deleteIncome = async (row) => {
    if (!confirm('Delete income source?')) return;
    await api.del(`/monetary/income/${row.id}`);
    show('Deleted');
    loadIncome();
  };

  /* Assets */
  const submitAsset = async (e) => {
    e.preventDefault();
    try {
      const payload = {
        asset_type: assetForm.asset_type,
        custom_type: assetForm.custom_type,
        amount: Number(assetForm.amount),
        notes: assetForm.notes,
      };
      if (assetEdit) {
        await api.put(`/monetary/assets/${assetEdit}`, payload);
        show('Asset updated');
      } else {
        await api.post('/monetary/assets', payload);
        show('Asset added');
      }
      setAssetForm(emptyAsset);
      setAssetEdit(null);
      loadAssets();
    } catch (err) {
      show(err.message, 'error');
    }
  };

  const editAsset = (row) => {
    setAssetEdit(row.id);
    setAssetForm({
      asset_type: row.asset_type,
      custom_type: '',
      amount: row.amount,
      notes: row.notes || '',
    });
    setAssetTab('entry');
    setTab('assets');
  };

  const deleteAsset = async (row) => {
    if (!confirm('Delete asset?')) return;
    await api.del(`/monetary/assets/${row.id}`);
    show('Deleted');
    loadAssets();
  };

  /* Money given */
  const submitGiven = async (e) => {
    e.preventDefault();
    try {
      const payload = {
        person_name: givenForm.person_name,
        given_date: givenForm.given_date,
        amount: Number(givenForm.amount),
        notes: givenForm.notes,
      };
      if (givenEdit) {
        await api.put(`/monetary/money-given/${givenEdit}`, payload);
        show('Updated');
      } else {
        await api.post('/monetary/money-given', payload);
        show('Entry added');
      }
      setGivenForm(emptyGiven);
      setGivenEdit(null);
      loadGiven();
    } catch (err) {
      show(err.message, 'error');
    }
  };

  const editGiven = (row) => {
    setGivenEdit(row.id);
    setGivenForm({
      person_name: row.person_name,
      given_date: String(row.given_date).slice(0, 10),
      amount: row.amount,
      notes: row.notes || '',
    });
    setGivenTab('entry');
    setTab('lent');
  };

  const deleteGiven = async (row) => {
    if (!confirm('Delete entry?')) return;
    await api.del(`/monetary/money-given/${row.id}`);
    show('Deleted');
    loadGiven();
  };

  const incomeColumns = [
    { key: 'source_name', label: 'Source' },
    {
      key: 'amount',
      label: 'Amount',
      render: (r) => formatCurrency(r.amount),
      export: (r) => Number(r.amount),
    },
    {
      key: 'period',
      label: 'Month',
      render: (r) => `${MONTHS[r.month - 1]} ${r.year}`,
      export: (r) => `${MONTHS[r.month - 1]} ${r.year}`,
    },
  ];

  const assetColumns = [
    {
      key: 'asset_type',
      label: 'Type',
      render: (r) => <span className="badge">{r.asset_type}</span>,
      export: (r) => r.asset_type,
    },
    {
      key: 'amount',
      label: 'Amount',
      render: (r) => formatCurrency(r.amount),
      export: (r) => Number(r.amount),
    },
    { key: 'notes', label: 'Notes' },
  ];

  const givenColumns = [
    { key: 'person_name', label: 'Person' },
    {
      key: 'given_date',
      label: 'Date',
      render: (r) => formatDate(r.given_date),
      export: (r) => String(r.given_date).slice(0, 10),
    },
    {
      key: 'amount',
      label: 'Amount',
      render: (r) => formatCurrency(r.amount),
      export: (r) => Number(r.amount),
    },
    { key: 'notes', label: 'Notes' },
  ];

  return (
    <div>
      {Toast}
      <Tabs
        tabs={[
          { id: 'income', label: 'Salary / Income' },
          { id: 'assets', label: 'Other Assets' },
          { id: 'lent', label: 'Money Lent' },
        ]}
        active={tab}
        onChange={setTab}
      />

      {tab === 'income' && (
        <>
          <Tabs
            tabs={[
              { id: 'entry', label: 'Entry' },
              { id: 'data', label: 'Data' },
            ]}
            active={incomeTab}
            onChange={setIncomeTab}
          />
          {incomeTab === 'entry' && (
            <>
              <div className="card">
                <h3>{incomeEdit ? 'Edit income source' : 'Add salary / income source'}</h3>
                <p className="muted">Add every monthly income source. Multiple sources allowed.</p>
                <form onSubmit={submitIncome} style={{ marginTop: '1rem' }}>
                  <div className="form-grid">
                    <div className="field">
                      <label>Income source</label>
                      <input
                        required
                        placeholder="Salary, Freelance, Rent…"
                        value={incomeForm.source_name}
                        onChange={(e) => setIncomeForm({ ...incomeForm, source_name: e.target.value })}
                      />
                    </div>
                    <div className="field">
                      <label>Amount (₹)</label>
                      <input
                        type="number"
                        min="0"
                        required
                        value={incomeForm.amount}
                        onChange={(e) => setIncomeForm({ ...incomeForm, amount: e.target.value })}
                      />
                    </div>
                    <div className="field">
                      <label>Month</label>
                      <GlassSelect
                        value={String(incomeForm.month)}
                        onChange={(v) => setIncomeForm({ ...incomeForm, month: v })}
                        placeholder="Month"
                        options={MONTHS.map((m, i) => ({ value: String(i + 1), label: m }))}
                      />
                    </div>
                    <div className="field">
                      <label>Year</label>
                      <input
                        type="number"
                        required
                        value={incomeForm.year}
                        onChange={(e) => setIncomeForm({ ...incomeForm, year: e.target.value })}
                      />
                    </div>
                  </div>
                  <div className="form-actions">
                    <button className="btn btn-primary" type="submit">
                      {incomeEdit ? 'Update' : 'Add income'}
                    </button>
                    {incomeEdit && (
                      <button
                        type="button"
                        className="btn btn-ghost"
                        onClick={() => {
                          setIncomeEdit(null);
                          setIncomeForm(emptyIncome);
                        }}
                      >
                        Cancel
                      </button>
                    )}
                  </div>
                </form>
              </div>
              <div className="card live-list">
                <h4>Live income entries</h4>
                <DataTable
                  columns={incomeColumns}
                  rows={incomes}
                  onEdit={editIncome}
                  onDelete={deleteIncome}
                  title="Income"
                  exportFilename="income"
                  filterMode="period"
                  monthKey="month"
                  yearKey="year"
                />
              </div>
            </>
          )}
          {incomeTab === 'data' && (
            <>
              <MonthYearFilters
                month={filterMonth}
                year={filterYear}
                onMonth={setFilterMonth}
                onYear={setFilterYear}
              />
              <div className="grid grid-3" style={{ marginBottom: '1.1rem' }}>
                <div className="card">
                  <h3>Income this month</h3>
                  <div className="metric">{formatCurrency(incomeSummary?.totalIncome)}</div>
                </div>
                <div className="card">
                  <h3>Spent till date (daily expense)</h3>
                  <div className="metric">{formatCurrency(incomeSummary?.totalSpend)}</div>
                </div>
                <div className="card">
                  <h3>Remaining balance</h3>
                  <div className="metric">{formatCurrency(incomeSummary?.balance)}</div>
                </div>
              </div>
              <div className="grid grid-2" style={{ marginBottom: '1.1rem' }}>
                <div className="card">
                  <h3>Income by source</h3>
                  <PieChart {...categoryChartData(incomeSummary?.bySource || [])} doughnut />
                </div>
                <div className="card">
                  <h3>Income vs Spend</h3>
                  <BarChart
                    labels={['Income', 'Spend', 'Balance']}
                    values={[
                      incomeSummary?.totalIncome || 0,
                      incomeSummary?.totalSpend || 0,
                      Math.max(incomeSummary?.balance || 0, 0),
                    ]}
                  />
                </div>
              </div>
              <div className="card">
                <DataTable
                  columns={incomeColumns}
                  rows={incomes}
                  onEdit={editIncome}
                  onDelete={deleteIncome}
                  title="Income"
                  exportFilename="income"
                  filterMode="period"
                  monthKey="month"
                  yearKey="year"
                />
              </div>
            </>
          )}
        </>
      )}

      {tab === 'assets' && (
        <>
          <Tabs
            tabs={[
              { id: 'entry', label: 'Entry' },
              { id: 'data', label: 'Data' },
            ]}
            active={assetTab}
            onChange={setAssetTab}
          />
          {assetTab === 'entry' && (
            <>
              <div className="card">
                <h3>{assetEdit ? 'Edit asset' : 'Add asset'}</h3>
                <form onSubmit={submitAsset} style={{ marginTop: '1rem' }}>
                  <div className="form-grid">
                    <CategorySelect
                      section="asset"
                      value={assetForm.asset_type}
                      onChange={(v) => setAssetForm({ ...assetForm, asset_type: v })}
                      customValue={assetForm.custom_type}
                      onCustomChange={(v) => setAssetForm({ ...assetForm, custom_type: v })}
                    />
                    <div className="field">
                      <label>Amount (₹)</label>
                      <input
                        type="number"
                        min="0"
                        required
                        value={assetForm.amount}
                        onChange={(e) => setAssetForm({ ...assetForm, amount: e.target.value })}
                      />
                    </div>
                    <div className="field">
                      <label>Notes</label>
                      <input
                        value={assetForm.notes}
                        onChange={(e) => setAssetForm({ ...assetForm, notes: e.target.value })}
                      />
                    </div>
                  </div>
                  <div className="form-actions">
                    <button className="btn btn-primary" type="submit">
                      {assetEdit ? 'Update' : 'Add asset'}
                    </button>
                    {assetEdit && (
                      <button
                        type="button"
                        className="btn btn-ghost"
                        onClick={() => {
                          setAssetEdit(null);
                          setAssetForm(emptyAsset);
                        }}
                      >
                        Cancel
                      </button>
                    )}
                  </div>
                </form>
              </div>
              <div className="card live-list">
                <h4>Live assets</h4>
                <DataTable
                  columns={assetColumns}
                  rows={assets}
                  onEdit={editAsset}
                  onDelete={deleteAsset}
                  title="Assets"
                  exportFilename="assets"
                  filterMode="none"
                />
              </div>
            </>
          )}
          {assetTab === 'data' && (
            <>
              <div className="grid grid-2" style={{ marginBottom: '1.1rem' }}>
                <div className="card">
                  <h3>Assets by type</h3>
                  <p className="muted">Total {formatCurrency(assetSummary?.total)}</p>
                  <PieChart {...categoryChartData(assetSummary?.byType || [])} doughnut />
                </div>
                <div className="card">
                  <h3>Amount by type</h3>
                  <BarChart
                    labels={(assetSummary?.byType || []).map((a) => a.name)}
                    values={(assetSummary?.byType || []).map((a) => a.amount)}
                  />
                </div>
              </div>
              <div className="card">
                <DataTable
                  columns={assetColumns}
                  rows={assets}
                  onEdit={editAsset}
                  onDelete={deleteAsset}
                  title="Assets"
                  exportFilename="assets"
                  filterMode="none"
                />
              </div>
            </>
          )}
        </>
      )}

      {tab === 'lent' && (
        <>
          <Tabs
            tabs={[
              { id: 'entry', label: 'Entry' },
              { id: 'data', label: 'Data' },
            ]}
            active={givenTab}
            onChange={setGivenTab}
          />
          {givenTab === 'entry' && (
            <>
              <div className="card">
                <h3>{givenEdit ? 'Edit entry' : 'Money given to people'}</h3>
                <p className="muted">Track how much you gave each person and when.</p>
                <form onSubmit={submitGiven} style={{ marginTop: '1rem' }}>
                  <div className="form-grid">
                    <div className="field">
                      <label>Person name</label>
                      <input
                        required
                        value={givenForm.person_name}
                        onChange={(e) => setGivenForm({ ...givenForm, person_name: e.target.value })}
                      />
                    </div>
                    <div className="field field-date">
                      <label>Date given</label>
                      <DateInput
                        required
                        value={givenForm.given_date}
                        onChange={(e) => setGivenForm({ ...givenForm, given_date: e.target.value })}
                      />
                    </div>
                    <div className="field">
                      <label>Amount (₹)</label>
                      <input
                        type="number"
                        min="0"
                        required
                        value={givenForm.amount}
                        onChange={(e) => setGivenForm({ ...givenForm, amount: e.target.value })}
                      />
                    </div>
                    <div className="field">
                      <label>Notes</label>
                      <input
                        value={givenForm.notes}
                        onChange={(e) => setGivenForm({ ...givenForm, notes: e.target.value })}
                      />
                    </div>
                  </div>
                  <div className="form-actions">
                    <button className="btn btn-primary" type="submit">
                      {givenEdit ? 'Update' : 'Add entry'}
                    </button>
                    {givenEdit && (
                      <button
                        type="button"
                        className="btn btn-ghost"
                        onClick={() => {
                          setGivenEdit(null);
                          setGivenForm(emptyGiven);
                        }}
                      >
                        Cancel
                      </button>
                    )}
                  </div>
                </form>
              </div>
              <div className="card live-list">
                <h4>Live entries</h4>
                <DataTable
                  columns={givenColumns}
                  rows={given}
                  onEdit={editGiven}
                  onDelete={deleteGiven}
                  title="Money Lent"
                  exportFilename="money_lent"
                  filterMode="date"
                  dateKey="given_date"
                />
              </div>
            </>
          )}
          {givenTab === 'data' && (
            <>
              <div className="grid grid-2" style={{ marginBottom: '1.1rem' }}>
                <div className="card">
                  <h3>Amount per person</h3>
                  <p className="muted">Total {formatCurrency(givenSummary?.total)}</p>
                  <PieChart {...categoryChartData(givenSummary?.byPerson || [])} doughnut />
                </div>
                <div className="card">
                  <h3>Bar chart by person</h3>
                  <BarChart
                    labels={(givenSummary?.byPerson || []).map((p) => p.name)}
                    values={(givenSummary?.byPerson || []).map((p) => p.amount)}
                  />
                </div>
              </div>
              <div className="card">
                <DataTable
                  columns={givenColumns}
                  rows={given}
                  onEdit={editGiven}
                  onDelete={deleteGiven}
                  title="Money Lent"
                  exportFilename="money_lent"
                  filterMode="date"
                  dateKey="given_date"
                />
              </div>
            </>
          )}
        </>
      )}
    </div>
  );
}
