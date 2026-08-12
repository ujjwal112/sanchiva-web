import { useCallback, useEffect, useMemo, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { api, formatCurrency, formatDate, todayISO } from '../api';
import { Tabs, DateInput, GlassSelect, DataTable, useToast } from '../components/ui';
import { useCurrency } from '../currency/CurrencyContext';

function balTone(n) {
  const v = Number(n) || 0;
  if (Math.abs(v) < 0.01) return 'neutral';
  return v > 0 ? 'pos' : 'neg';
}

function formatDateTime(d) {
  if (!d) return '—';
  const x = new Date(d);
  if (Number.isNaN(x.getTime())) return String(d);
  return x.toLocaleString('en-IN', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function balText(n, { you = false } = {}) {
  const v = Number(n) || 0;
  if (Math.abs(v) < 0.01) return 'Settled up';
  if (you) {
    return v > 0 ? `You are owed ${formatCurrency(v)}` : `You owe ${formatCurrency(-v)}`;
  }
  return v > 0 ? `+${formatCurrency(v)}` : formatCurrency(v);
}

function memberName(m) {
  if (!m) return '—';
  return m.is_you ? 'You' : m.name;
}

function GroupsHome({ groups, loading, onRefresh, onOpen, show, Toast }) {
  const { symbol: currencySymbol } = useCurrency();
  const [name, setName] = useState('');
  const [notes, setNotes] = useState('');
  const [members, setMembers] = useState([]);
  const [memberDraft, setMemberDraft] = useState('');
  const [saving, setSaving] = useState(false);

  const netYou = useMemo(
    () => groups.reduce((s, g) => s + (Number(g.your_balance) || 0), 0),
    [groups]
  );

  const addMemberRow = () => {
    const n = memberDraft.trim();
    if (!n) {
      show('Enter a member name', 'error');
      return;
    }
    if (n.toLowerCase() === 'you') {
      show('“You” is already in every group', 'error');
      return;
    }
    const exists = members.some((m) => m.toLowerCase() === n.toLowerCase());
    if (exists) {
      show('That member is already added', 'error');
      return;
    }
    setMembers((prev) => [...prev, n]);
    setMemberDraft('');
  };

  const removeMember = (idx) => {
    setMembers((prev) => prev.filter((_, i) => i !== idx));
  };

  const createGroup = async (e) => {
    e.preventDefault();
    if (!name.trim()) {
      show('Enter a group name', 'error');
      return;
    }
    // Include draft name if user typed but didn't press +
    let finalMembers = [...members];
    const draft = memberDraft.trim();
    if (draft && draft.toLowerCase() !== 'you') {
      if (!finalMembers.some((m) => m.toLowerCase() === draft.toLowerCase())) {
        finalMembers = [...finalMembers, draft];
      }
    }
    setSaving(true);
    try {
      const g = await api.post('/splits/groups', {
        name: name.trim(),
        notes: notes.trim() || null,
        members: finalMembers,
      });
      show('Group created');
      setName('');
      setNotes('');
      setMembers([]);
      setMemberDraft('');
      await onRefresh();
      if (g?.id) onOpen(g.id);
    } catch (err) {
      show(err.message, 'error');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div>
      {Toast}

      <div className="grid grid-2" style={{ marginBottom: '1.1rem' }}>
        <div className="card">
          <h3>Your overall balance</h3>
          <p className="muted">Across all split groups</p>
          <div className={`metric splits-bal splits-bal--${balTone(netYou)}`}>
            {balText(netYou, { you: true })}
          </div>
        </div>
        <div className="card">
          <h3>Groups</h3>
          <p className="muted">Active shared-expense groups</p>
          <div className="metric">{groups.length}</div>
        </div>
      </div>

      <div className="card" style={{ marginBottom: '1.1rem' }}>
        <h3>New group</h3>
        <p className="muted">You are always included. Add friends one by one with +.</p>
        <form onSubmit={createGroup} style={{ marginTop: '1rem' }}>
          <div className="form-grid">
            <div className="field">
              <label>Group name</label>
              <input
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="e.g. Goa trip, Flatmates"
                required
              />
            </div>
            <div className="field">
              <label>Notes (optional)</label>
              <input
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                placeholder="Optional note"
              />
            </div>
            <div className="field" style={{ gridColumn: '1 / -1' }}>
              <label>Members</label>
              <div className="splits-member-builder">
                <div className="splits-member-builder__you">
                  <span className="chip selected">★ You</span>
                  <span className="muted" style={{ fontSize: 12 }}>
                    Always in the group
                  </span>
                </div>
                {members.length > 0 && (
                  <ul className="splits-member-builder__list">
                    {members.map((m, i) => (
                      <li key={`${m}-${i}`} className="splits-member-builder__row">
                        <span className="chip selected">{m}</span>
                        <button
                          type="button"
                          className="btn btn-ghost btn-sm splits-member-builder__remove"
                          onClick={() => removeMember(i)}
                          aria-label={`Remove ${m}`}
                          title="Remove"
                        >
                          ×
                        </button>
                      </li>
                    ))}
                  </ul>
                )}
                <div className="splits-member-builder__add">
                  <input
                    value={memberDraft}
                    onChange={(e) => setMemberDraft(e.target.value)}
                    placeholder="Friend name"
                    onKeyDown={(e) => {
                      if (e.key === 'Enter') {
                        e.preventDefault();
                        addMemberRow();
                      }
                    }}
                  />
                  <button
                    type="button"
                    className="btn btn-primary splits-member-builder__plus"
                    onClick={addMemberRow}
                    title="Add member"
                    aria-label="Add member"
                  >
                    <span aria-hidden>+</span>
                    <span className="splits-member-builder__plus-label">Add</span>
                  </button>
                </div>
              </div>
            </div>
            <div className="form-actions">
              <button type="submit" className="btn btn-primary" disabled={saving}>
                {saving ? 'Creating…' : 'Create group'}
              </button>
            </div>
          </div>
        </form>
      </div>

      <div className="card live-list">
        <div className="splits-list-head">
          <div>
            <h4>Your groups</h4>
            <p className="muted" style={{ margin: 0 }}>
              Open a group to add expenses and settle balances · {currencySymbol}
            </p>
          </div>
          <button type="button" className="btn btn-ghost btn-sm" onClick={onRefresh}>
            Refresh
          </button>
        </div>

        {loading ? (
          <p className="muted" style={{ marginTop: '1rem' }}>
            Loading…
          </p>
        ) : !groups.length ? (
          <div className="empty" style={{ marginTop: '1rem' }}>
            <span className="emoji">⇋</span>
            No groups yet. Create one above to start splitting bills.
          </div>
        ) : (
          <ul className="splits-group-list">
            {groups.map((g) => {
              const tone = balTone(g.your_balance);
              return (
                <li key={g.id}>
                  <button type="button" className="splits-group-card" onClick={() => onOpen(g.id)}>
                    <div className="splits-group-card__avatar" aria-hidden>
                      {(g.name || '?').charAt(0).toUpperCase()}
                    </div>
                    <div className="splits-group-card__main">
                      <strong>{g.name}</strong>
                      <span className="muted">
                        {g.member_count ?? 0} member{(g.member_count || 0) === 1 ? '' : 's'}
                        {' · '}
                        {formatCurrency(g.total_spent)} spent
                      </span>
                      {g.notes ? <span className="muted splits-group-card__notes">{g.notes}</span> : null}
                    </div>
                    <div className={`splits-group-card__bal splits-bal--${tone}`}>
                      {balText(g.your_balance, { you: true })}
                    </div>
                    <span className="splits-group-card__chev" aria-hidden>
                      →
                    </span>
                  </button>
                </li>
              );
            })}
          </ul>
        )}
      </div>
    </div>
  );
}

function GroupDetail({ groupId, show, Toast }) {
  const navigate = useNavigate();
  const { symbol: currencySymbol } = useCurrency();
  const [detail, setDetail] = useState(null);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState('expenses');

  const [desc, setDesc] = useState('');
  const [amount, setAmount] = useState('');
  const [paidBy, setPaidBy] = useState('');
  const [expDate, setExpDate] = useState(todayISO());
  const [expNotes, setExpNotes] = useState('');
  const [splitIds, setSplitIds] = useState([]);
  const [savingExp, setSavingExp] = useState(false);
  const [editingExpenseId, setEditingExpenseId] = useState(null);
  const [historyNote, setHistoryNote] = useState('');
  const [historyExpense, setHistoryExpense] = useState(null);
  const [amountHistory, setAmountHistory] = useState([]);
  const [historyLoading, setHistoryLoading] = useState(false);

  const [fromId, setFromId] = useState('');
  const [toId, setToId] = useState('');
  const [settleAmt, setSettleAmt] = useState('');
  const [settleDate, setSettleDate] = useState(todayISO());
  const [settleNotes, setSettleNotes] = useState('');
  const [savingSettle, setSavingSettle] = useState(false);

  const [newMember, setNewMember] = useState('');

  const resetExpenseForm = (members) => {
    const list = members || detail?.members || [];
    const you = list.find((m) => m.is_you);
    setEditingExpenseId(null);
    setDesc('');
    setAmount('');
    setExpNotes('');
    setHistoryNote('');
    setExpDate(todayISO());
    setPaidBy(String(you?.id || list[0]?.id || ''));
    setSplitIds(list.map((m) => m.id));
  };

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const d = await api.get(`/splits/groups/${groupId}`);
      setDetail(d);
      const you = (d.members || []).find((m) => m.is_you);
      const firstOther = (d.members || []).find((m) => !m.is_you);
      // Only reset payer/split defaults when not editing
      setEditingExpenseId((cur) => {
        if (cur == null) {
          setPaidBy(String(you?.id || d.members?.[0]?.id || ''));
          setSplitIds((d.members || []).map((m) => m.id));
        }
        return cur;
      });
      setFromId(String(you?.id || d.members?.[0]?.id || ''));
      setToId(String(firstOther?.id || d.members?.[1]?.id || ''));
    } catch (e) {
      show(e.message, 'error');
    } finally {
      setLoading(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps -- show is unstable from useToast
  }, [groupId]);

  useEffect(() => {
    load();
  }, [load]);

  const memberOptions = useMemo(
    () =>
      (detail?.members || []).map((m) => ({
        value: String(m.id),
        label: memberName(m),
      })),
    [detail]
  );

  const toggleSplit = (id) => {
    setSplitIds((prev) => {
      if (prev.includes(id)) {
        if (prev.length <= 1) return prev;
        return prev.filter((x) => x !== id);
      }
      return [...prev, id];
    });
  };

  const startEditExpense = (row) => {
    setEditingExpenseId(row.id);
    setDesc(row.description || '');
    setAmount(String(row.amount ?? ''));
    setPaidBy(String(row.paid_by_member_id || ''));
    setExpDate(
      row.expense_date
        ? String(row.expense_date).slice(0, 10)
        : todayISO()
    );
    setExpNotes(row.notes || '');
    setHistoryNote('');
    const ids = (row.shares || []).map((s) => s.member_id).filter(Boolean);
    setSplitIds(ids.length ? ids : (detail?.members || []).map((m) => m.id));
    setTab('expenses');
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const saveExpense = async (e) => {
    e.preventDefault();
    setSavingExp(true);
    try {
      const payload = {
        description: desc.trim(),
        amount: Number(amount),
        paid_by_member_id: Number(paidBy),
        expense_date: expDate,
        notes: expNotes.trim() || null,
        split_member_ids: splitIds,
      };
      let updated = null;
      const editedId = editingExpenseId;
      if (editingExpenseId) {
        if (historyNote.trim()) payload.history_note = historyNote.trim();
        updated = await api.put(
          `/splits/groups/${groupId}/expenses/${editingExpenseId}`,
          payload
        );
        show(
          updated?.amount_changed
            ? 'Expense updated · amount change logged'
            : 'Expense updated'
        );
      } else {
        await api.post(`/splits/groups/${groupId}/expenses`, payload);
        show('Expense added');
      }
      resetExpenseForm(detail?.members);
      await load();
      // After amount change, open history panel so the edit is visible immediately
      if (updated?.amount_changed && editedId) {
        setTimeout(() => {
          openAmountHistory({
            id: editedId,
            description: payload.description,
            amount_history: [],
          });
        }, 50);
      }
    } catch (err) {
      show(err.message, 'error');
    } finally {
      setSavingExp(false);
    }
  };

  const deleteExpense = async (row) => {
    if (!confirm('Delete this expense?')) return;
    try {
      await api.del(`/splits/groups/${groupId}/expenses/${row.id}`);
      show('Expense deleted');
      if (editingExpenseId === row.id) resetExpenseForm(detail?.members);
      if (historyExpense?.id === row.id) {
        setHistoryExpense(null);
        setAmountHistory([]);
      }
      load();
    } catch (err) {
      show(err.message, 'error');
    }
  };

  const openAmountHistory = async (row) => {
    setHistoryExpense(row);
    // Prefer embedded history from group detail (instant), then refresh from API
    const embedded = row.amount_history || [];
    if (embedded.length) {
      setAmountHistory(embedded);
      setHistoryLoading(false);
    } else {
      setHistoryLoading(true);
      setAmountHistory([]);
    }
    try {
      const rows = await api.get(
        `/splits/groups/${groupId}/expenses/${row.id}/amount-history`
      );
      setAmountHistory(Array.isArray(rows) ? rows : embedded);
    } catch (err) {
      if (!embedded.length) show(err.message, 'error');
      if (!embedded.length) setAmountHistory([]);
    } finally {
      setHistoryLoading(false);
      setTimeout(() => {
        document.getElementById('splits-amount-history')?.scrollIntoView({
          behavior: 'smooth',
          block: 'nearest',
        });
      }, 80);
    }
  };

  const addSettlement = async (e) => {
    e.preventDefault();
    setSavingSettle(true);
    try {
      await api.post(`/splits/groups/${groupId}/settlements`, {
        from_member_id: Number(fromId),
        to_member_id: Number(toId),
        amount: Number(settleAmt),
        settled_date: settleDate,
        notes: settleNotes.trim() || null,
      });
      show('Settlement recorded');
      setSettleAmt('');
      setSettleNotes('');
      setSettleDate(todayISO());
      await load();
    } catch (err) {
      show(err.message, 'error');
    } finally {
      setSavingSettle(false);
    }
  };

  const deleteSettlement = async (row) => {
    if (!confirm('Delete this settlement?')) return;
    try {
      await api.del(`/splits/groups/${groupId}/settlements/${row.id}`);
      show('Settlement deleted');
      load();
    } catch (err) {
      show(err.message, 'error');
    }
  };

  const addMember = async (e) => {
    e.preventDefault();
    if (!newMember.trim()) return;
    try {
      await api.post(`/splits/groups/${groupId}/members`, { name: newMember.trim() });
      show('Member added');
      setNewMember('');
      load();
    } catch (err) {
      show(err.message, 'error');
    }
  };

  const deleteGroup = async () => {
    if (!confirm(`Delete group “${detail?.name}” and all its data?`)) return;
    try {
      await api.del(`/splits/groups/${groupId}`);
      show('Group deleted');
      navigate('/splits');
    } catch (err) {
      show(err.message, 'error');
    }
  };

  const applyTransfer = (t) => {
    setFromId(String(t.from_member_id));
    setToId(String(t.to_member_id));
    setSettleAmt(String(t.amount));
    setTab('settle');
  };

  if (loading && !detail) {
    return (
      <div>
        {Toast}
        <div className="card">Loading group…</div>
      </div>
    );
  }

  if (!detail) {
    return (
      <div>
        {Toast}
        <div className="card">
          <p className="muted">Group not found.</p>
          <button type="button" className="btn btn-ghost" onClick={() => navigate('/splits')}>
            ← Back to groups
          </button>
        </div>
      </div>
    );
  }

  const youTone = balTone(detail.your_balance);

  const expenseColumns = [
    {
      key: 'description',
      label: 'Description',
      render: (r) => (
        <div>
          <strong>{r.description}</strong>
          {r.notes ? <div className="muted" style={{ fontSize: 12 }}>{r.notes}</div> : null}
          {(r.amount_edit_count || 0) > 0 ? (
            <span className="splits-edited-badge">Amount edited {r.amount_edit_count}×</span>
          ) : null}
        </div>
      ),
    },
    {
      key: 'paid_by',
      label: 'Paid by',
      render: (r) => (r.paid_by_is_you ? 'You' : r.paid_by_name),
    },
    {
      key: 'expense_date',
      label: 'Date',
      render: (r) => formatDate(r.expense_date),
    },
    {
      key: 'amount',
      label: 'Amount',
      render: (r) => {
        const last = r.last_amount_change;
        return (
          <div className="splits-amount-cell">
            <strong className="splits-amount-cell__now">{formatCurrency(r.amount)}</strong>
            {last ? (
              <div className="splits-amount-cell__was">
                was <span className="splits-amount-cell__old">{formatCurrency(last.old_amount)}</span>
              </div>
            ) : null}
            <button
              type="button"
              className="btn btn-ghost btn-sm splits-hist-link"
              onClick={(e) => {
                e.stopPropagation();
                openAmountHistory(r);
              }}
            >
              {(r.amount_edit_count || 0) > 0
                ? `View history (${r.amount_edit_count})`
                : 'View history'}
            </button>
          </div>
        );
      },
    },
    {
      key: 'split',
      label: 'Split',
      render: (r) => {
        const n = (r.shares || []).length;
        const each = r.shares?.[0]?.share_amount;
        return n ? `${n} ways${each != null ? ` · ${formatCurrency(each)}` : ''}` : '—';
      },
    },
  ];

  const settlementColumns = [
    {
      key: 'pair',
      label: 'From → To',
      render: (s) =>
        `${s.from_is_you ? 'You' : s.from_name} → ${s.to_is_you ? 'You' : s.to_name}`,
    },
    {
      key: 'settled_date',
      label: 'Date',
      render: (s) => formatDate(s.settled_date),
    },
    {
      key: 'amount',
      label: 'Amount',
      render: (s) => formatCurrency(s.amount),
    },
    {
      key: 'notes',
      label: 'Notes',
      render: (s) => s.notes || '—',
    },
  ];

  return (
    <div>
      {Toast}

      <div className="splits-detail-head card">
        <div className="splits-detail-head__left">
          <button type="button" className="btn btn-ghost btn-sm" onClick={() => navigate('/splits')}>
            ← All groups
          </button>
          <h3 style={{ margin: '0.5rem 0 0.15rem' }}>{detail.name}</h3>
          <p className="muted" style={{ margin: 0 }}>
            {(detail.members || []).length} members · {formatCurrency(detail.total_spent)} total
            {detail.notes ? ` · ${detail.notes}` : ''}
          </p>
        </div>
        <button type="button" className="btn btn-danger btn-sm" onClick={deleteGroup}>
          Delete group
        </button>
      </div>

      <div className="grid grid-2" style={{ margin: '1.1rem 0' }}>
        <div className="card">
          <h3>Your balance</h3>
          <p className="muted">In this group</p>
          <div className={`metric splits-bal splits-bal--${youTone}`}>
            {balText(detail.your_balance, { you: true })}
          </div>
        </div>
        <div className="card">
          <h3>Group spend</h3>
          <p className="muted">All shared expenses</p>
          <div className="metric">{formatCurrency(detail.total_spent)}</div>
        </div>
      </div>

      {(detail.transfers || []).length > 0 && (
        <div className="card" style={{ marginBottom: '1.1rem' }}>
          <h3>Settle suggestions</h3>
          <p className="muted">Tap Record to prefill a settlement</p>
          <ul className="splits-transfer-list">
            {detail.transfers.map((t, i) => (
              <li key={i} className="splits-transfer-item">
                <div>
                  <strong>{t.from_name}</strong>
                  <span className="muted"> pays </span>
                  <strong>{t.to_name}</strong>
                </div>
                <div className="splits-transfer-item__amt">{formatCurrency(t.amount)}</div>
                <button type="button" className="btn btn-primary btn-sm" onClick={() => applyTransfer(t)}>
                  Record
                </button>
              </li>
            ))}
          </ul>
        </div>
      )}

      <Tabs
        tabs={[
          { id: 'expenses', label: 'Expenses' },
          { id: 'balances', label: 'Balances' },
          { id: 'settle', label: 'Settlements' },
        ]}
        active={tab}
        onChange={setTab}
      />

      {tab === 'expenses' && (
        <>
          <div className="card" style={{ marginTop: '1rem' }}>
            <h3>{editingExpenseId ? 'Edit expense' : 'Add expense'}</h3>
            {editingExpenseId ? (
              <p className="muted">
                Changing the amount is logged in history. Other fields update the expense and re-split shares.
              </p>
            ) : null}
            <form onSubmit={saveExpense} style={{ marginTop: '1rem' }}>
              <div className="form-grid">
                <div className="field" style={{ gridColumn: '1 / -1' }}>
                  <label>Description</label>
                  <input
                    value={desc}
                    onChange={(e) => setDesc(e.target.value)}
                    placeholder="e.g. Dinner, Taxi, Groceries"
                    required
                  />
                </div>
                <div className="field">
                  <label>Amount ({currencySymbol})</label>
                  <input
                    type="number"
                    min="0.01"
                    step="0.01"
                    value={amount}
                    onChange={(e) => setAmount(e.target.value)}
                    required
                  />
                </div>
                <div className="field field-date">
                  <label>Date</label>
                  <DateInput
                    required
                    value={expDate}
                    onChange={(e) => setExpDate(e.target.value)}
                  />
                </div>
                <div className="field">
                  <label>Paid by</label>
                  <GlassSelect value={paidBy} onChange={setPaidBy} options={memberOptions} />
                </div>
                <div className="field">
                  <label>Notes (optional)</label>
                  <input value={expNotes} onChange={(e) => setExpNotes(e.target.value)} />
                </div>
                {editingExpenseId ? (
                  <div className="field" style={{ gridColumn: '1 / -1' }}>
                    <label>Amount-change note (optional)</label>
                    <input
                      value={historyNote}
                      onChange={(e) => setHistoryNote(e.target.value)}
                      placeholder="Why did the amount change? e.g. Added tip"
                    />
                  </div>
                ) : null}
                <div className="field" style={{ gridColumn: '1 / -1' }}>
                  <label>Split equally among</label>
                  <div className="checkbox-row splits-member-chips">
                    {(detail.members || []).map((m) => {
                      const on = splitIds.includes(m.id);
                      return (
                        <button
                          key={m.id}
                          type="button"
                          className={`chip${on ? ' selected' : ''}`}
                          onClick={() => toggleSplit(m.id)}
                        >
                          {memberName(m)}
                        </button>
                      );
                    })}
                  </div>
                </div>
                <div className="form-actions">
                  <button type="submit" className="btn btn-primary" disabled={savingExp}>
                    {savingExp
                      ? 'Saving…'
                      : editingExpenseId
                        ? 'Update expense'
                        : 'Add expense'}
                  </button>
                  {editingExpenseId ? (
                    <button
                      type="button"
                      className="btn btn-ghost"
                      onClick={() => resetExpenseForm(detail.members)}
                    >
                      Cancel
                    </button>
                  ) : null}
                </div>
              </div>
            </form>
          </div>

          {historyExpense && (
            <div className="card splits-history-card" style={{ marginTop: '1.1rem' }} id="splits-amount-history">
              <div className="splits-list-head">
                <div>
                  <h4>Amount change history</h4>
                  <p className="muted" style={{ margin: 0 }}>
                    <strong>{historyExpense.description || 'Expense'}</strong>
                    {' · '}newest first
                  </p>
                </div>
                <button
                  type="button"
                  className="btn btn-ghost btn-sm"
                  onClick={() => {
                    setHistoryExpense(null);
                    setAmountHistory([]);
                  }}
                >
                  Close
                </button>
              </div>
              {historyLoading ? (
                <p className="muted" style={{ marginTop: '0.75rem' }}>
                  Loading history…
                </p>
              ) : !amountHistory.length ? (
                <div className="empty" style={{ marginTop: '0.75rem' }}>
                  <span className="emoji">🕘</span>
                  No amount changes yet. Edit this expense and change the amount to create history.
                </div>
              ) : (
                <ul className="splits-history-timeline">
                  {amountHistory.map((h) => (
                    <li key={h.id} className="splits-history-timeline__item">
                      <div className="splits-history-timeline__dot" aria-hidden />
                      <div className="splits-history-timeline__body">
                        <div className="splits-history-timeline__change">
                          <span className="splits-amount-cell__old">{formatCurrency(h.old_amount)}</span>
                          <span className="splits-recent-edits__arrow">→</span>
                          <strong className="splits-history-timeline__new">
                            {formatCurrency(h.new_amount)}
                          </strong>
                        </div>
                        <div className="muted splits-history-timeline__meta">
                          {formatDateTime(h.created_at)}
                          {' · '}
                          {h.changed_by_name || h.changed_by_email || 'User'}
                        </div>
                        {h.note ? (
                          <div className="splits-history-timeline__note">{h.note}</div>
                        ) : null}
                      </div>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          )}

          <div className="card live-list" style={{ marginTop: '1.1rem' }}>
            <h4>Expenses</h4>
            {!(detail.expenses || []).length ? (
              <div className="empty">
                <span className="emoji">🧾</span>
                No expenses yet. Add a bill above.
              </div>
            ) : (
              <DataTable
                columns={expenseColumns}
                rows={detail.expenses}
                onEdit={startEditExpense}
                onDelete={deleteExpense}
                title="Split expenses"
                exportFilename={`splits_${detail.name || 'group'}_expenses`}
                filterMode="none"
              />
            )}
          </div>
        </>
      )}

      {tab === 'balances' && (
        <>
          <div className="card" style={{ marginTop: '1rem' }}>
            <h3>Member balances</h3>
            <p className="muted">Positive = owed money · Negative = owes money</p>
            <ul className="splits-balance-list">
              {(detail.balances || []).map((b) => {
                const tone = balTone(b.balance);
                return (
                  <li key={b.id} className="splits-balance-row">
                    <div className="splits-group-card__avatar" aria-hidden>
                      {(b.is_you ? 'Y' : b.name || '?').charAt(0).toUpperCase()}
                    </div>
                    <strong>{b.is_you ? 'You' : b.name}</strong>
                    <span className={`splits-bal splits-bal--${tone}`}>{balText(b.balance)}</span>
                  </li>
                );
              })}
            </ul>
          </div>

          <div className="card" style={{ marginTop: '1.1rem' }}>
            <h3>Members</h3>
            <div className="checkbox-row splits-member-chips" style={{ marginBottom: '1rem' }}>
              {(detail.members || []).map((m) => (
                <span key={m.id} className="chip selected">
                  {m.is_you ? '★ ' : ''}
                  {memberName(m)}
                </span>
              ))}
            </div>
            <form onSubmit={addMember} className="splits-add-member">
              <div className="field" style={{ flex: 1, minWidth: 180 }}>
                <label>Add member</label>
                <input
                  value={newMember}
                  onChange={(e) => setNewMember(e.target.value)}
                  placeholder="Name"
                />
              </div>
              <button type="submit" className="btn btn-primary" style={{ alignSelf: 'flex-end' }}>
                Add
              </button>
            </form>
          </div>
        </>
      )}

      {tab === 'settle' && (
        <>
          <div className="card" style={{ marginTop: '1rem' }}>
            <h3>Record settlement</h3>
            <p className="muted">Mark that one person paid another to clear a balance.</p>
            <form onSubmit={addSettlement} style={{ marginTop: '1rem' }}>
              <div className="form-grid">
                <div className="field">
                  <label>From (who paid)</label>
                  <GlassSelect value={fromId} onChange={setFromId} options={memberOptions} />
                </div>
                <div className="field">
                  <label>To (who received)</label>
                  <GlassSelect value={toId} onChange={setToId} options={memberOptions} />
                </div>
                <div className="field">
                  <label>Amount ({currencySymbol})</label>
                  <input
                    type="number"
                    min="0.01"
                    step="0.01"
                    value={settleAmt}
                    onChange={(e) => setSettleAmt(e.target.value)}
                    required
                  />
                </div>
                <div className="field field-date">
                  <label>Date</label>
                  <DateInput
                    required
                    value={settleDate}
                    onChange={(e) => setSettleDate(e.target.value)}
                  />
                </div>
                <div className="field" style={{ gridColumn: '1 / -1' }}>
                  <label>Notes (optional)</label>
                  <input
                    value={settleNotes}
                    onChange={(e) => setSettleNotes(e.target.value)}
                    placeholder="e.g. UPI, cash"
                  />
                </div>
                <div className="form-actions">
                  <button type="submit" className="btn btn-primary" disabled={savingSettle}>
                    {savingSettle ? 'Saving…' : 'Record settlement'}
                  </button>
                </div>
              </div>
            </form>
          </div>

          <div className="card live-list" style={{ marginTop: '1.1rem' }}>
            <h4>Settlement history</h4>
            {!(detail.settlements || []).length ? (
              <div className="empty">
                <span className="emoji">🤝</span>
                No settlements yet.
              </div>
            ) : (
              <DataTable
                columns={settlementColumns}
                rows={detail.settlements}
                onDelete={deleteSettlement}
                title="Settlements"
                exportFilename={`splits_${detail.name || 'group'}_settlements`}
                filterMode="none"
              />
            )}
          </div>
        </>
      )}
    </div>
  );
}

export default function Splits() {
  const { groupId } = useParams();
  const navigate = useNavigate();
  const [groups, setGroups] = useState([]);
  const [loading, setLoading] = useState(true);
  const { show, Toast } = useToast();

  const loadGroups = useCallback(async () => {
    setLoading(true);
    try {
      const list = await api.get('/splits/groups');
      // api.get may return a bare array or wrap it
      const rows = Array.isArray(list)
        ? list
        : Array.isArray(list?.items)
          ? list.items
          : Array.isArray(list?.data)
            ? list.data
            : [];
      setGroups(rows);
    } catch (e) {
      show(e.message, 'error');
      setGroups([]);
    } finally {
      setLoading(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps -- show is unstable from useToast
  }, []);

  useEffect(() => {
    if (!groupId) loadGroups();
  }, [groupId, loadGroups]);

  if (groupId) {
    return <GroupDetail groupId={groupId} show={show} Toast={Toast} />;
  }

  return (
    <GroupsHome
      groups={groups}
      loading={loading}
      onRefresh={loadGroups}
      onOpen={(id) => navigate(`/splits/${id}`)}
      show={show}
      Toast={Toast}
    />
  );
}
