import { useCallback, useEffect, useMemo, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { api, formatCurrency, formatDate, formatEventStyleLabel } from '../api';
import { Tabs, DateInput, useToast } from '../components/ui';
import { PieChart, BarChart } from '../components/Charts';
import { downloadExcel, downloadExcelMulti, downloadPdf } from '../utils/export';
import { buildCeremonyCards, getCeremonyTheme } from '../utils/ceremonyThemes';

const GUEST_PAGE_SIZE = 10;
const TODO_PAGE_SIZE = 10;

export default function EventDetail() {
  const { eventId } = useParams();
  const navigate = useNavigate();
  const { show, Toast } = useToast();

  const [detail, setDetail] = useState(null);
  const [loading, setLoading] = useState(true);
  const [section, setSection] = useState('overview'); // overview | charts | todos | guests

  const [itemForm, setItemForm] = useState({
    title: '',
    category: '',
    planned_amount: '',
    token_paid: '',
    vendor_name: '',
  });
  const [editingTodo, setEditingTodo] = useState(null);
  const [todoPage, setTodoPage] = useState(1);
  const [guestForm, setGuestForm] = useState({
    name: '',
    side: '',
    count: 1,
    rsvp: 'maybe',
    ceremony: '',
  });
  const [editingGuest, setEditingGuest] = useState(null);
  const [guestCeremonyTab, setGuestCeremonyTab] = useState('');
  const [guestPage, setGuestPage] = useState(1);
  const [editingCeremony, setEditingCeremony] = useState(null); // original ceremony name
  const [ceremonyEditForm, setCeremonyEditForm] = useState({ name: '', date: '' });
  const [savingCeremony, setSavingCeremony] = useState(false);

  const toDateInputValue = (d) => {
    if (!d) return '';
    const s = String(d);
    if (/^\d{4}-\d{2}-\d{2}/.test(s)) return s.slice(0, 10);
    const dt = new Date(d);
    if (Number.isNaN(dt.getTime())) return '';
    return dt.toISOString().slice(0, 10);
  };

  const loadDetail = useCallback(() => {
    if (!eventId) return;
    setLoading(true);
    api
      .get(`/events/${eventId}`)
      .then((d) => {
        setDetail(d);
        const tabs = (d.ceremonies || []).filter(
          (c) => c && String(c).toLowerCase() !== 'general' && c !== 'Other'
        );
        const first = tabs[0] || '';
        setGuestCeremonyTab((prev) => (tabs.includes(prev) ? prev : first));
        setGuestForm((f) => ({
          ...f,
          ceremony: tabs.includes(f.ceremony) ? f.ceremony : first,
        }));
      })
      .catch((e) => {
        show(e.message, 'error');
        setDetail(null);
      })
      .finally(() => setLoading(false));
  }, [eventId]);

  useEffect(() => {
    loadDetail();
  }, [loadDetail]);

  useEffect(() => {
    setGuestPage(1);
  }, [guestCeremonyTab, eventId]);

  useEffect(() => {
    setTodoPage(1);
  }, [eventId]);

  const items = detail?.items || [];
  const guests = detail?.guests || [];

  const ceremonyTabs = useMemo(() => {
    if (!detail) return [];
    return (detail.ceremonies || []).filter(
      (c) => c && String(c).toLowerCase() !== 'general' && c !== 'Other'
    );
  }, [detail]);

  const ceremonyCards = useMemo(() => {
    if (!detail) return [];
    const fromApi =
      detail.ceremony_details ||
      detail.metadata?.ceremony_details ||
      [];
    if (fromApi?.length) return buildCeremonyCards(fromApi);
    return buildCeremonyCards(ceremonyTabs.map((name) => ({ name, date: null })));
  }, [detail, ceremonyTabs]);

  const guestsForTab = useMemo(() => {
    if (!detail || !guestCeremonyTab) return [];
    return (
      detail.guestsByCeremony?.[guestCeremonyTab] ||
      guests.filter((g) => (g.ceremony || '') === guestCeremonyTab)
    );
  }, [detail, guestCeremonyTab, guests]);

  const guestTotalPages = Math.max(1, Math.ceil(guestsForTab.length / GUEST_PAGE_SIZE));
  const pagedGuests = guestsForTab.slice(
    (guestPage - 1) * GUEST_PAGE_SIZE,
    guestPage * GUEST_PAGE_SIZE
  );

  const todoTotalPages = Math.max(1, Math.ceil(items.length / TODO_PAGE_SIZE));
  const safeTodoPage = Math.min(todoPage, todoTotalPages);
  const pagedTodos = items.slice(
    (safeTodoPage - 1) * TODO_PAGE_SIZE,
    safeTodoPage * TODO_PAGE_SIZE
  );

  const byCat = {};
  for (const it of items) {
    const k = it.category || 'Other';
    byCat[k] = (byCat[k] || 0) + Number(it.planned_amount);
  }
  const paidPct = detail?.summary?.planned
    ? Math.min(100, (detail.summary.paid / detail.summary.planned) * 100)
    : 0;

  const resetItemForm = () => {
    setItemForm({ title: '', category: '', planned_amount: '', token_paid: '', vendor_name: '' });
    setEditingTodo(null);
  };

  const addItem = async (e) => {
    e.preventDefault();
    try {
      const payload = {
        title: itemForm.title,
        category: itemForm.category,
        vendor_name: itemForm.vendor_name,
        planned_amount: Number(itemForm.planned_amount || 0),
        token_paid: Number(itemForm.token_paid || 0),
      };
      if (editingTodo) {
        await api.put(`/events/items/${editingTodo.id}`, payload);
        show('Todo updated');
      } else {
        await api.post(`/events/${eventId}/items`, payload);
        show('Todo item added');
      }
      resetItemForm();
      loadDetail();
    } catch (err) {
      show(err.message, 'error');
    }
  };

  const startEditTodo = (item) => {
    setEditingTodo(item);
    setItemForm({
      title: item.title || '',
      category: item.category || '',
      planned_amount: item.planned_amount ?? '',
      token_paid: item.token_paid ?? '',
      vendor_name: item.vendor_name || '',
    });
    // Form sits above the list, scroll so user can edit task name + fields
    requestAnimationFrame(() => {
      document.getElementById('todo-entry-form')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
  };

  const updateItem = async (item, patch) => {
    try {
      await api.put(`/events/items/${item.id}`, patch);
      loadDetail();
    } catch (err) {
      show(err.message, 'error');
    }
  };

  const deleteItem = async (item) => {
    if (!confirm('Delete this item?')) return;
    await api.del(`/events/items/${item.id}`);
    if (editingTodo?.id === item.id) resetItemForm();
    loadDetail();
    show('Item deleted');
  };

  const exportTodos = (format) => {
    if (!detail) return;
    const todoCols = [
      { key: 'title', label: 'Task' },
      { key: 'category', label: 'Category' },
      { key: 'vendor_name', label: 'Vendor' },
      { key: 'planned_amount', label: 'Planned', export: (r) => Number(r.planned_amount) || 0 },
      { key: 'token_paid', label: 'Token paid', export: (r) => Number(r.token_paid) || 0 },
      {
        key: 'remaining_amount',
        label: 'Remaining',
        export: (r) =>
          Number(r.remaining_amount) ||
          Math.max(Number(r.planned_amount || 0) - Number(r.token_paid || 0), 0),
      },
      {
        key: 'is_done',
        label: 'Done',
        export: (r) => (r.is_done ? 'Yes' : 'No'),
      },
    ];
    const rows = detail.items || [];
    if (!rows.length) {
      show('No todos to export', 'error');
      return;
    }
    const fname = `todos_${(detail.name || 'event').replace(/\s+/g, '_')}`;
    if (format === 'excel') {
      downloadExcel({
        filename: fname,
        sheetName: 'Todos',
        columns: todoCols,
        rows,
      });
      show('Todo Excel downloaded');
    } else {
      downloadPdf({
        columns: todoCols,
        rows,
        filename: fname,
        title: `${detail.name}, Todo / bookings list`,
      });
      show('Todo PDF downloaded');
    }
  };

  const addGuest = async (e) => {
    e.preventDefault();
    const ceremony = guestForm.ceremony || guestCeremonyTab || ceremonyTabs[0] || '';
    if (!ceremony) {
      show('Select a ceremony first. Create the event with ceremonies in the wizard.', 'error');
      return;
    }
    try {
      const payload = {
        ...guestForm,
        ceremony,
        count: Number(guestForm.count || 1),
        rsvp: guestForm.rsvp || 'maybe',
      };
      if (editingGuest) {
        await api.put(`/events/guests/${editingGuest.id}`, payload);
        show('Guest updated');
      } else {
        await api.post(`/events/${eventId}/guests`, payload);
        show('Guest added');
      }
      setGuestForm({
        name: '',
        side: '',
        count: 1,
        rsvp: 'maybe',
        ceremony: guestCeremonyTab || ceremonyTabs[0] || '',
      });
      setEditingGuest(null);
      loadDetail();
    } catch (err) {
      show(err.message, 'error');
    }
  };

  const startEditGuest = (g) => {
    setEditingGuest(g);
    setGuestForm({
      name: g.name || '',
      side: g.side || '',
      count: g.count || 1,
      rsvp: ['yes', 'no', 'maybe'].includes(g.rsvp) ? g.rsvp : 'maybe',
      ceremony: g.ceremony || guestCeremonyTab || ceremonyTabs[0] || '',
    });
    if (g.ceremony) setGuestCeremonyTab(g.ceremony);
  };

  const cancelEditGuest = () => {
    setEditingGuest(null);
    setGuestForm({
      name: '',
      side: '',
      count: 1,
      rsvp: 'maybe',
      ceremony: guestCeremonyTab || ceremonyTabs[0] || '',
    });
  };

  const startEditCeremony = (card) => {
    setEditingCeremony(card.name);
    setCeremonyEditForm({
      name: card.name || '',
      date: toDateInputValue(card.date),
    });
  };

  const cancelEditCeremony = () => {
    setEditingCeremony(null);
    setCeremonyEditForm({ name: '', date: '' });
  };

  const saveCeremony = async (e) => {
    e.preventDefault();
    if (!editingCeremony) return;
    const name = ceremonyEditForm.name.trim();
    if (!name) {
      show('Ceremony name is required', 'error');
      return;
    }
    setSavingCeremony(true);
    try {
      await api.put(`/events/${eventId}/ceremonies`, {
        originalName: editingCeremony,
        name,
        date: ceremonyEditForm.date || null,
      });
      show('Ceremony updated');
      // Keep guest tab in sync if the open ceremony was renamed
      if (guestCeremonyTab === editingCeremony && name !== editingCeremony) {
        setGuestCeremonyTab(name);
      }
      cancelEditCeremony();
      loadDetail();
    } catch (err) {
      show(err.message, 'error');
    } finally {
      setSavingCeremony(false);
    }
  };

  const deleteGuest = async (g) => {
    if (!confirm('Remove guest?')) return;
    await api.del(`/events/guests/${g.id}`);
    if (editingGuest?.id === g.id) cancelEditGuest();
    loadDetail();
  };

  const exportGuests = (format) => {
    if (!detail) return;
    const ceremonies = (detail.ceremonies || []).filter(
      (c) => c && String(c).toLowerCase() !== 'general' && c !== 'Other'
    );
    const guestCols = [
      { key: 'name', label: 'Name' },
      { key: 'side', label: 'Side' },
      { key: 'ceremony', label: 'Ceremony' },
      { key: 'count', label: 'Count', export: (r) => Number(r.count) || 1 },
      { key: 'rsvp', label: 'RSVP' },
    ];
    const allGuests = detail.guests || [];
    if (!allGuests.length) {
      show('No guests to export', 'error');
      return;
    }
    const summaryRows = ceremonies.map((c) => ({
      ceremony: c,
      guest_entries: (detail.guestsByCeremony?.[c] || []).length,
      headcount: detail.ceremonyCounts?.[c] || 0,
    }));
    const fname = `guests_${(detail.name || 'event').replace(/\s+/g, '_')}`;
    if (format === 'excel') {
      downloadExcelMulti({
        filename: fname,
        sheets: [
          {
            name: 'Summary',
            columns: [
              { key: 'ceremony', label: 'Ceremony' },
              { key: 'guest_entries', label: 'Guest entries' },
              { key: 'headcount', label: 'Total headcount' },
            ],
            rows: summaryRows,
          },
          ...ceremonies.map((c) => ({
            name: String(c).slice(0, 31),
            columns: guestCols,
            rows: detail.guestsByCeremony?.[c] || [],
          })),
        ],
      });
      show('Excel downloaded');
    } else {
      downloadPdf({
        columns: [
          { key: 'ceremony', label: 'Ceremony' },
          { key: 'headcount', label: 'Guest count' },
        ],
        rows: summaryRows.map((r) => ({ ceremony: r.ceremony, headcount: r.headcount })),
        filename: `${fname}_summary`,
        title: `${detail.name}, Guest count by ceremony`,
      });
      downloadPdf({
        columns: guestCols,
        rows: allGuests,
        filename: `${fname}_all`,
        title: `${detail.name}, Full guest list`,
      });
      show('PDF downloaded');
    }
  };

  if (loading) {
    return (
      <div className="card">
        <p className="muted">Loading event…</p>
      </div>
    );
  }

  if (!detail) {
    return (
      <div className="card">
        <p className="muted">Event not found.</p>
        <button type="button" className="btn btn-primary" onClick={() => navigate('/events?tab=list')}>
          Back to My Events
        </button>
      </div>
    );
  }

  return (
    <div className="event-detail-page">
      {Toast}

      <div className="event-detail-heading">
        <p className="event-section-label">Event</p>
        <h2 className="event-detail-title">{detail.name}</h2>
        <p className="muted">{formatEventStyleLabel(detail.event_type, detail.sub_type)}</p>
      </div>

      <div className="event-detail-tabs-row">
        <Tabs
          tabs={[
            { id: 'overview', label: 'Overview' },
            { id: 'charts', label: 'Budget charts' },
            { id: 'todos', label: 'Todos' },
            { id: 'guests', label: 'Guests' },
          ]}
          active={section}
          onChange={setSection}
        />
        <button
          type="button"
          className="btn btn-ghost event-back-my-events"
          onClick={() => navigate('/events?tab=list')}
        >
          ← My Events
        </button>
      </div>

      {section === 'overview' && (
        <>
          <section className="card event-section">
            <div className="event-section-header">
              <div>
                <p className="event-section-label">Overview</p>
                <h3>Budget & progress</h3>
              </div>
              <span className="badge warning">{detail.status}</span>
            </div>
            <div className="event-kpi-row">
              <div className="event-kpi">
                <span className="muted">Total budget</span>
                <strong>{formatCurrency(detail.budget ?? detail.metadata?.budget ?? 0)}</strong>
              </div>
              <div className="event-kpi">
                <span className="muted">Planned</span>
                <strong>{formatCurrency(detail.summary?.planned)}</strong>
              </div>
              <div className="event-kpi">
                <span className="muted">Token paid</span>
                <strong>{formatCurrency(detail.summary?.paid)}</strong>
              </div>
              <div className="event-kpi">
                <span className="muted">Remaining</span>
                <strong>{formatCurrency(detail.summary?.remaining)}</strong>
              </div>
              <div className="event-kpi">
                <span className="muted">Tasks done</span>
                <strong>
                  {detail.summary?.itemsDone}/{detail.summary?.itemsTotal}
                </strong>
              </div>
            </div>
            <div className="progress-bar" style={{ marginTop: '0.85rem' }}>
              <span style={{ width: `${paidPct}%` }} />
            </div>
            <p className="muted" style={{ fontSize: '0.8rem', marginTop: '0.4rem' }}>
              {paidPct.toFixed(0)}% of planned budget paid as token · Guests headcount{' '}
              {detail.summary?.guestCount || 0}
            </p>
          </section>

          {!!ceremonyCards.length && (
            <section className="event-section ceremony-cards-section">
              <div className="event-section-header" style={{ marginBottom: '0.85rem' }}>
                <div>
                  <p className="event-section-label">Ceremonies</p>
                  <h3>Dates & blessings</h3>
                </div>
              </div>
              <div className="ceremony-cards-grid">
                {ceremonyCards.map((card) => {
                  const isEditing = editingCeremony === card.name;
                  const theme = getCeremonyTheme(isEditing ? ceremonyEditForm.name || card.name : card.name);
                  return (
                    <article
                      key={card.name}
                      className={`ceremony-card ceremony-card--${theme.key}${isEditing ? ' ceremony-card--editing' : ''}`}
                      style={{
                        background: theme.bg,
                        borderColor: theme.border,
                      }}
                    >
                      {isEditing ? (
                        <form className="ceremony-card-edit-form" onSubmit={saveCeremony}>
                          <div className="field">
                            <label>Ceremony name</label>
                            <input
                              required
                              value={ceremonyEditForm.name}
                              onChange={(e) =>
                                setCeremonyEditForm((f) => ({ ...f, name: e.target.value }))
                              }
                              placeholder="Ceremony name"
                              autoFocus
                            />
                          </div>
                          <div className="field field-date">
                            <label>Date</label>
                            <DateInput
                              value={ceremonyEditForm.date}
                              onChange={(e) =>
                                setCeremonyEditForm((f) => ({ ...f, date: e.target.value }))
                              }
                            />
                          </div>
                          <div className="ceremony-card-edit-actions">
                            <button
                              type="submit"
                              className="btn btn-primary btn-sm"
                              disabled={savingCeremony}
                            >
                              {savingCeremony ? 'Saving…' : 'Save'}
                            </button>
                            <button
                              type="button"
                              className="btn btn-ghost btn-sm"
                              onClick={cancelEditCeremony}
                              disabled={savingCeremony}
                            >
                              Cancel
                            </button>
                          </div>
                        </form>
                      ) : (
                        <>
                          <div className="ceremony-card-top">
                            <h4 className="ceremony-card-name" style={{ color: theme.accent }}>
                              {card.name}
                            </h4>
                            <button
                              type="button"
                              className="btn btn-ghost btn-sm ceremony-card-edit-btn"
                              onClick={() => startEditCeremony(card)}
                            >
                              Edit
                            </button>
                          </div>
                          <p className="ceremony-card-date">
                            {card.date ? formatDate(card.date) : 'Date not set'}
                          </p>
                          <blockquote className="ceremony-card-quote" style={{ color: theme.text }}>
                            “{card.quote}”
                          </blockquote>
                        </>
                      )}
                    </article>
                  );
                })}
              </div>
            </section>
          )}
        </>
      )}

      {section === 'charts' && (
        <section className="card event-section">
          <p className="event-section-label">Budget charts</p>
          <div className="event-charts-grid">
            <div className="event-chart-card">
              <h4>By category</h4>
              <div className="event-chart-box">
                <PieChart labels={Object.keys(byCat)} values={Object.values(byCat)} doughnut />
              </div>
            </div>
            <div className="event-chart-card">
              <h4>Paid vs remaining</h4>
              <div className="event-chart-box">
                <BarChart
                  labels={['Paid', 'Remaining']}
                  values={[detail.summary?.paid || 0, detail.summary?.remaining || 0]}
                />
              </div>
            </div>
          </div>
        </section>
      )}

      {section === 'todos' && (
        <section className="card event-section">
          <div className="event-section-header">
            <div>
              <p className="event-section-label">Todos & bookings</p>
              <h3>
                Checklist · {detail.summary?.itemsDone}/{detail.summary?.itemsTotal} done
              </h3>
            </div>
            <div className="event-export-actions">
              <button type="button" className="btn btn-ghost btn-sm" onClick={() => exportTodos('excel')}>
                ⬇ Excel
              </button>
              <button type="button" className="btn btn-ghost btn-sm" onClick={() => exportTodos('pdf')}>
                ⬇ PDF
              </button>
            </div>
          </div>

          {/* Entry / edit form at top of list */}
          <div id="todo-entry-form">
            {editingTodo && (
              <div className="todo-edit-banner">
                <span>
                  Editing task: <strong>{editingTodo.title || 'Untitled'}</strong>. Change the task name and other fields below, then click Update todo.
                </span>
                <button type="button" className="btn btn-ghost btn-sm" onClick={resetItemForm}>
                  Cancel edit
                </button>
              </div>
            )}
            <form
              onSubmit={addItem}
              className="form-grid event-add-form"
              style={{ borderTop: 'none', paddingTop: 0, marginBottom: '1rem' }}
            >
              <div className="field">
                <label>Task name</label>
                <input
                  required
                  value={itemForm.title}
                  onChange={(e) => setItemForm({ ...itemForm, title: e.target.value })}
                  placeholder="Task name"
                />
              </div>
              <div className="field">
                <label>Category</label>
                <input
                  value={itemForm.category}
                  onChange={(e) => setItemForm({ ...itemForm, category: e.target.value })}
                  placeholder="e.g. Catering"
                />
              </div>
              <div className="field">
                <label>Vendor</label>
                <input
                  value={itemForm.vendor_name}
                  onChange={(e) => setItemForm({ ...itemForm, vendor_name: e.target.value })}
                  placeholder="Vendor name"
                />
              </div>
              <div className="field">
                <label>Planned ₹</label>
                <input
                  type="number"
                  value={itemForm.planned_amount}
                  onChange={(e) => setItemForm({ ...itemForm, planned_amount: e.target.value })}
                />
              </div>
              <div className="field">
                <label>Token paid ₹</label>
                <input
                  type="number"
                  value={itemForm.token_paid}
                  onChange={(e) => setItemForm({ ...itemForm, token_paid: e.target.value })}
                />
              </div>
              <div className="form-actions" style={{ alignItems: 'end' }}>
                <button className="btn btn-primary" type="submit">
                  {editingTodo ? 'Update todo' : 'Add task'}
                </button>
                {editingTodo && (
                  <button type="button" className="btn btn-ghost" onClick={resetItemForm}>
                    Cancel
                  </button>
                )}
              </div>
            </form>
          </div>

          <div className="list-toolbar" style={{ marginTop: '0.25rem' }}>
            <span className="muted list-count">
              {items.length
                ? `Showing ${(safeTodoPage - 1) * TODO_PAGE_SIZE + 1}–${Math.min(
                    safeTodoPage * TODO_PAGE_SIZE,
                    items.length
                  )} of ${items.length} tasks`
                : 'No tasks yet'}
            </span>
          </div>
          <div className="table-wrap event-table-wrap">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Done</th>
                  <th>Task</th>
                  <th>Vendor</th>
                  <th>Planned</th>
                  <th>Token</th>
                  <th>Left</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {pagedTodos.map((it) => (
                  <tr key={it.id} className={editingTodo?.id === it.id ? 'row-editing' : ''}>
                    <td>
                      <input
                        type="checkbox"
                        checked={!!it.is_done}
                        onChange={(e) => updateItem(it, { is_done: e.target.checked })}
                      />
                    </td>
                    <td>
                      <div>{it.title}</div>
                      <span className="muted" style={{ fontSize: '0.75rem' }}>
                        {it.category}
                      </span>
                    </td>
                    <td>{it.vendor_name || '-'}</td>
                    <td>{formatCurrency(it.planned_amount)}</td>
                    <td>{formatCurrency(it.token_paid)}</td>
                    <td>{formatCurrency(it.remaining_amount)}</td>
                    <td>
                      <div className="row-actions">
                        <button type="button" className="btn btn-ghost btn-sm" onClick={() => startEditTodo(it)}>
                          Edit
                        </button>
                        <button type="button" className="btn btn-danger btn-sm" onClick={() => deleteItem(it)}>
                          Delete
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
                {!items.length && (
                  <tr>
                    <td colSpan={7} className="muted" style={{ textAlign: 'center' }}>
                      No tasks yet. Add one above.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
          {todoTotalPages > 1 && (
            <div className="pagination">
              <button
                type="button"
                className="btn btn-ghost btn-sm"
                disabled={safeTodoPage <= 1}
                onClick={() => setTodoPage(Math.max(1, safeTodoPage - 1))}
              >
                ← Prev
              </button>
              <span className="muted">
                Page {safeTodoPage} / {todoTotalPages}
              </span>
              <button
                type="button"
                className="btn btn-ghost btn-sm"
                disabled={safeTodoPage >= todoTotalPages}
                onClick={() => setTodoPage(Math.min(todoTotalPages, safeTodoPage + 1))}
              >
                Next →
              </button>
            </div>
          )}
        </section>
      )}

      {section === 'guests' && (
        <section className="card event-section">
          <div className="event-section-header">
            <div>
              <p className="event-section-label">Guests</p>
              <h3>
                Ceremony-wise lists · {detail.summary?.guestCount || 0} total headcount
              </h3>
            </div>
            <div className="event-export-actions">
              <button type="button" className="btn btn-ghost btn-sm" onClick={() => exportGuests('excel')}>
                ⬇ Excel
              </button>
              <button type="button" className="btn btn-ghost btn-sm" onClick={() => exportGuests('pdf')}>
                ⬇ PDF
              </button>
            </div>
          </div>

          {!ceremonyTabs.length ? (
            <p className="muted" style={{ marginBottom: '1rem' }}>
              No ceremonies for this event yet. Create a wedding event and pick ceremonies (with dates) in the wizard to organise guests by ceremony.
            </p>
          ) : (
            <div className="ceremony-tabs">
              {ceremonyTabs.map((c) => (
                <button
                  key={c}
                  type="button"
                  className={`tab ${guestCeremonyTab === c ? 'active' : ''}`}
                  onClick={() => {
                    setGuestCeremonyTab(c);
                    setEditingGuest(null);
                    setGuestForm({
                      name: '',
                      side: '',
                      count: 1,
                      rsvp: 'maybe',
                      ceremony: c,
                    });
                  }}
                >
                  {c}
                  <span className="badge" style={{ marginLeft: 6 }}>
                    {detail.ceremonyCounts?.[c] || 0}
                  </span>
                </button>
              ))}
            </div>
          )}

          <form onSubmit={addGuest} className="form-grid event-add-form" style={{ borderTop: 'none', paddingTop: 0 }}>
            <div className="field">
              <label>Guest name</label>
              <input
                required
                value={guestForm.name}
                onChange={(e) => setGuestForm({ ...guestForm, name: e.target.value })}
                disabled={!ceremonyTabs.length}
              />
            </div>
            <div className="field">
              <label>Side</label>
              <input
                placeholder="Bride / Groom / Friend"
                value={guestForm.side}
                onChange={(e) => setGuestForm({ ...guestForm, side: e.target.value })}
                disabled={!ceremonyTabs.length}
              />
            </div>
            <div className="field">
              <label>Ceremony</label>
              <select
                value={guestForm.ceremony || guestCeremonyTab || ''}
                onChange={(e) => {
                  setGuestForm({ ...guestForm, ceremony: e.target.value });
                  setGuestCeremonyTab(e.target.value);
                }}
                disabled={!ceremonyTabs.length}
                required
              >
                {!ceremonyTabs.length && <option value="">No ceremonies</option>}
                {ceremonyTabs.map((c) => (
                  <option key={c} value={c}>
                    {c}
                  </option>
                ))}
              </select>
            </div>
            <div className="field">
              <label>Count</label>
              <input
                type="number"
                min="1"
                value={guestForm.count}
                onChange={(e) => setGuestForm({ ...guestForm, count: e.target.value })}
              />
            </div>
            <div className="field">
              <label>RSVP</label>
              <select
                value={guestForm.rsvp}
                onChange={(e) => setGuestForm({ ...guestForm, rsvp: e.target.value })}
              >
                <option value="yes">Yes</option>
                <option value="no">No</option>
                <option value="maybe">Maybe</option>
              </select>
            </div>
            <div className="form-actions" style={{ alignItems: 'end' }}>
              <button className="btn btn-primary" type="submit" disabled={!ceremonyTabs.length}>
                {editingGuest ? 'Update guest' : 'Add guest'}
              </button>
              {editingGuest && (
                <button type="button" className="btn btn-ghost" onClick={cancelEditGuest}>
                  Cancel
                </button>
              )}
            </div>
          </form>

          <div className="list-toolbar" style={{ marginTop: '1rem' }}>
            <span className="muted list-count">
              {!ceremonyTabs.length
                ? 'No ceremony selected'
                : guestsForTab.length
                  ? `Showing ${(guestPage - 1) * GUEST_PAGE_SIZE + 1}–${Math.min(
                      guestPage * GUEST_PAGE_SIZE,
                      guestsForTab.length
                    )} of ${guestsForTab.length} · ${guestCeremonyTab}`
                  : `No guests for ${guestCeremonyTab || 'this ceremony'}`}
            </span>
          </div>
          <div className="table-wrap event-table-wrap">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Side</th>
                  <th>Count</th>
                  <th>RSVP</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {pagedGuests.map((g) => (
                  <tr key={g.id}>
                    <td>{g.name}</td>
                    <td>{g.side || '-'}</td>
                    <td>{g.count}</td>
                    <td>
                      <span className="badge">{g.rsvp}</span>
                    </td>
                    <td>
                      <div className="row-actions">
                        <button type="button" className="btn btn-ghost btn-sm" onClick={() => startEditGuest(g)}>
                          Edit
                        </button>
                        <button type="button" className="btn btn-danger btn-sm" onClick={() => deleteGuest(g)}>
                          Delete
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
                {!pagedGuests.length && (
                  <tr>
                    <td colSpan={5} className="muted" style={{ textAlign: 'center' }}>
                      No guests yet for this ceremony. Add one above.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
          {guestTotalPages > 1 && (
            <div className="pagination">
              <button
                type="button"
                className="btn btn-ghost btn-sm"
                disabled={guestPage <= 1}
                onClick={() => setGuestPage((p) => Math.max(1, p - 1))}
              >
                ← Prev
              </button>
              <span className="muted">
                Page {guestPage} / {guestTotalPages}
              </span>
              <button
                type="button"
                className="btn btn-ghost btn-sm"
                disabled={guestPage >= guestTotalPages}
                onClick={() => setGuestPage((p) => Math.min(guestTotalPages, p + 1))}
              >
                Next →
              </button>
            </div>
          )}
        </section>
      )}
    </div>
  );
}
