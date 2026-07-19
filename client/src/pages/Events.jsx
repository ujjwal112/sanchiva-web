import { useCallback, useEffect, useState } from 'react';
import { api, formatCurrency, formatDate, todayISO } from '../api';
import { Tabs, useToast } from '../components/ui';
import { PieChart, BarChart } from '../components/Charts';

const EVENT_TYPES = [
  { id: 'wedding', label: 'Wedding', icon: '💍' },
  { id: 'birthday', label: 'Birthday', icon: '🎂' },
  { id: 'anniversary', label: 'Anniversary', icon: '💞' },
  { id: 'housewarming', label: 'Housewarming', icon: '🏠' },
  { id: 'corporate', label: 'Corporate', icon: '🏢' },
  { id: 'other', label: 'Other event', icon: '✦' },
];

export default function Events() {
  const [tab, setTab] = useState('create');
  const [events, setEvents] = useState([]);
  const [selected, setSelected] = useState(null);
  const [detail, setDetail] = useState(null);

  // Wizard state
  const [step, setStep] = useState('pick'); // pick | questions | done
  const [eventType, setEventType] = useState(null);
  const [questions, setQuestions] = useState([]);
  const [intro, setIntro] = useState('');
  const [qIndex, setQIndex] = useState(0);
  const [answers, setAnswers] = useState({});
  const [currentAnswer, setCurrentAnswer] = useState('');
  const [multiSel, setMultiSel] = useState([]);
  const [chat, setChat] = useState([]);
  const [creating, setCreating] = useState(false);

  // Item / guest forms
  const [itemForm, setItemForm] = useState({
    title: '',
    category: '',
    planned_amount: '',
    token_paid: '',
    vendor_name: '',
  });
  const [guestForm, setGuestForm] = useState({ name: '', side: '', count: 1, rsvp: 'pending' });

  const { show, Toast } = useToast();

  const loadEvents = useCallback(() => {
    api.get('/events').then(setEvents).catch((e) => show(e.message, 'error'));
  }, []);

  const loadDetail = useCallback(
    (id) => {
      if (!id) return;
      api
        .get(`/events/${id}`)
        .then(setDetail)
        .catch((e) => show(e.message, 'error'));
    },
    []
  );

  useEffect(() => {
    loadEvents();
  }, [loadEvents]);

  useEffect(() => {
    if (selected) loadDetail(selected);
  }, [selected, loadDetail]);

  const startWizard = async (type) => {
    setEventType(type);
    try {
      const data = await api.get(`/events/meta/wizard-questions/${type}`);
      setQuestions(data.questions || []);
      setIntro(data.intro || '');
      setQIndex(0);
      setAnswers({});
      setCurrentAnswer('');
      setMultiSel([]);
      setChat([{ role: 'ai', text: data.intro }]);
      setStep('questions');
    } catch (e) {
      show(e.message, 'error');
    }
  };

  const currentQ = questions[qIndex];

  const pushAnswer = async () => {
    if (!currentQ) return;
    let value = currentAnswer;
    if (currentQ.type === 'multiselect') value = multiSel;
    if (currentQ.type === 'number') value = currentAnswer === '' ? '' : Number(currentAnswer);
    if (currentQ.required && (value === '' || value == null || (Array.isArray(value) && !value.length))) {
      show('This field is required', 'error');
      return;
    }

    const nextAnswers = { ...answers, [currentQ.id]: value };
    if (currentQ.id === 'name') nextAnswers.name = value;

    setChat((c) => [
      ...c,
      { role: 'ai', text: currentQ.label },
      { role: 'user', text: Array.isArray(value) ? value.join(', ') : String(value || '—') },
    ]);
    setAnswers(nextAnswers);
    setCurrentAnswer(currentQ.default != null ? String(currentQ.default) : '');
    setMultiSel([]);

    if (qIndex + 1 < questions.length) {
      setQIndex(qIndex + 1);
    } else {
      // Finish — create event
      setCreating(true);
      try {
        const name = nextAnswers.name || `${eventType} event`;
        const created = await api.post('/events/wizard', {
          name,
          event_type: eventType,
          answers: nextAnswers,
          generate_todos: true,
        });
        show('Event created with smart checklist');
        setStep('done');
        setChat((c) => [
          ...c,
          {
            role: 'ai',
            text: `All set! I created “${created.name}” with ${created.items?.length || 0} planned tasks. Open it under My Events to track tokens, budgets and guests.`,
          },
        ]);
        loadEvents();
        setSelected(created.id);
      } catch (e) {
        show(e.message, 'error');
      } finally {
        setCreating(false);
      }
    }
  };

  const resetWizard = () => {
    setStep('pick');
    setEventType(null);
    setQuestions([]);
    setQIndex(0);
    setAnswers({});
    setChat([]);
  };

  const addItem = async (e) => {
    e.preventDefault();
    if (!selected) return;
    try {
      await api.post(`/events/${selected}/items`, {
        ...itemForm,
        planned_amount: Number(itemForm.planned_amount || 0),
        token_paid: Number(itemForm.token_paid || 0),
      });
      setItemForm({ title: '', category: '', planned_amount: '', token_paid: '', vendor_name: '' });
      loadDetail(selected);
      show('Todo item added');
    } catch (err) {
      show(err.message, 'error');
    }
  };

  const updateItem = async (item, patch) => {
    try {
      await api.put(`/events/items/${item.id}`, patch);
      loadDetail(selected);
    } catch (err) {
      show(err.message, 'error');
    }
  };

  const deleteItem = async (item) => {
    if (!confirm('Delete this item?')) return;
    await api.del(`/events/items/${item.id}`);
    loadDetail(selected);
    show('Item deleted');
  };

  const addGuest = async (e) => {
    e.preventDefault();
    if (!selected) return;
    try {
      await api.post(`/events/${selected}/guests`, {
        ...guestForm,
        count: Number(guestForm.count || 1),
      });
      setGuestForm({ name: '', side: '', count: 1, rsvp: 'pending' });
      loadDetail(selected);
      show('Guest added');
    } catch (err) {
      show(err.message, 'error');
    }
  };

  const deleteGuest = async (g) => {
    if (!confirm('Remove guest?')) return;
    await api.del(`/events/guests/${g.id}`);
    loadDetail(selected);
  };

  const deleteEvent = async (ev) => {
    if (!confirm(`Delete event “${ev.name}”?`)) return;
    await api.del(`/events/${ev.id}`);
    if (selected === ev.id) {
      setSelected(null);
      setDetail(null);
    }
    loadEvents();
    show('Event deleted');
  };

  const items = detail?.items || [];
  const guests = detail?.guests || [];
  const byCat = {};
  for (const it of items) {
    const k = it.category || 'Other';
    byCat[k] = (byCat[k] || 0) + Number(it.planned_amount);
  }

  return (
    <div>
      {Toast}
      <Tabs
        tabs={[
          { id: 'create', label: 'Create Event (AI wizard)' },
          { id: 'list', label: 'My Events' },
        ]}
        active={tab}
        onChange={setTab}
      />

      {tab === 'create' && (
        <div className="card wizard">
          {step === 'pick' && (
            <>
              <h3>What are we planning?</h3>
              <p className="muted" style={{ marginBottom: '1rem' }}>
                I am your event planning agent. Pick a type and I will ask the right questions, then build a
                checklist with venues, vendors, budgets and guest tracking.
              </p>
              <div className="grid grid-3">
                {EVENT_TYPES.map((t) => (
                  <button
                    key={t.id}
                    type="button"
                    className="card"
                    style={{ cursor: 'pointer', textAlign: 'left' }}
                    onClick={() => startWizard(t.id)}
                  >
                    <div style={{ fontSize: '1.6rem' }}>{t.icon}</div>
                    <h3 style={{ marginTop: '0.5rem' }}>{t.label}</h3>
                    <p className="muted">Smart questionnaire + todo tracker</p>
                  </button>
                ))}
              </div>
            </>
          )}

          {step === 'questions' && currentQ && (
            <>
              <div className="flex-between" style={{ marginBottom: '0.75rem' }}>
                <div>
                  <h3>
                    Planning · {eventType}{' '}
                    <span className="badge">
                      {qIndex + 1}/{questions.length}
                    </span>
                  </h3>
                  <p className="muted">{intro}</p>
                </div>
                <button type="button" className="btn btn-ghost btn-sm" onClick={resetWizard}>
                  Start over
                </button>
              </div>
              <div className="progress-bar" style={{ marginBottom: '1rem' }}>
                <span style={{ width: `${((qIndex + 1) / questions.length) * 100}%` }} />
              </div>

              <div className="wizard-chat">
                {chat.map((m, i) => (
                  <div key={i} className={`bubble ${m.role === 'ai' ? 'ai' : 'user'}`}>
                    {m.text}
                  </div>
                ))}
                <div className="bubble ai">
                  <strong>{currentQ.label}</strong>
                  {currentQ.required && <span className="badge" style={{ marginLeft: 8 }}>required</span>}
                </div>
              </div>

              <div style={{ marginTop: '1rem' }}>
                {currentQ.type === 'select' && (
                  <div className="field">
                    <select value={currentAnswer} onChange={(e) => setCurrentAnswer(e.target.value)}>
                      <option value="">Select…</option>
                      {(currentQ.options || []).map((o) => (
                        <option key={o} value={o}>
                          {o}
                        </option>
                      ))}
                    </select>
                  </div>
                )}
                {currentQ.type === 'multiselect' && (
                  <div className="checkbox-row">
                    {(currentQ.options || []).map((o) => {
                      const on = multiSel.includes(o);
                      return (
                        <button
                          key={o}
                          type="button"
                          className={`chip ${on ? 'selected' : ''}`}
                          onClick={() =>
                            setMultiSel((s) => (on ? s.filter((x) => x !== o) : [...s, o]))
                          }
                        >
                          {o}
                        </button>
                      );
                    })}
                  </div>
                )}
                {['text', 'number', 'date'].includes(currentQ.type) && (
                  <div className="field">
                    <input
                      type={currentQ.type === 'text' ? 'text' : currentQ.type}
                      value={currentAnswer}
                      onChange={(e) => setCurrentAnswer(e.target.value)}
                      placeholder="Your answer…"
                      onKeyDown={(e) => e.key === 'Enter' && pushAnswer()}
                    />
                  </div>
                )}
                {currentQ.type === 'textarea' && (
                  <div className="field">
                    <textarea value={currentAnswer} onChange={(e) => setCurrentAnswer(e.target.value)} />
                  </div>
                )}
                <div className="form-actions" style={{ marginTop: '0.75rem' }}>
                  <button type="button" className="btn btn-primary" onClick={pushAnswer} disabled={creating}>
                    {qIndex + 1 >= questions.length ? (creating ? 'Creating…' : 'Create event') : 'Next'}
                  </button>
                  {!currentQ.required && qIndex + 1 < questions.length && (
                    <button
                      type="button"
                      className="btn btn-ghost"
                      onClick={() => {
                        setCurrentAnswer('');
                        setMultiSel([]);
                        setQIndex(qIndex + 1);
                      }}
                    >
                      Skip
                    </button>
                  )}
                </div>
              </div>
            </>
          )}

          {step === 'done' && (
            <>
              <div className="wizard-chat">
                {chat.slice(-4).map((m, i) => (
                  <div key={i} className={`bubble ${m.role === 'ai' ? 'ai' : 'user'}`}>
                    {m.text}
                  </div>
                ))}
              </div>
              <div className="form-actions" style={{ marginTop: '1rem' }}>
                <button type="button" className="btn btn-primary" onClick={() => setTab('list')}>
                  Open My Events
                </button>
                <button type="button" className="btn btn-ghost" onClick={resetWizard}>
                  Create another
                </button>
              </div>
            </>
          )}
        </div>
      )}

      {tab === 'list' && (
        <div className="grid grid-2">
          <div className="card">
            <h3>Your events</h3>
            {!events.length && (
              <div className="empty">
                <span className="emoji">✦</span>
                No events yet — create one with the AI wizard.
              </div>
            )}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '0.6rem', marginTop: '0.75rem' }}>
              {events.map((ev) => (
                <div
                  key={ev.id}
                  className="card"
                  style={{
                    padding: '0.85rem',
                    cursor: 'pointer',
                    borderColor: selected === ev.id ? 'rgba(124,108,255,0.55)' : undefined,
                  }}
                  onClick={() => setSelected(ev.id)}
                >
                  <div className="flex-between">
                    <div>
                      <strong>{ev.name}</strong>
                      <p className="muted">
                        {ev.event_type}
                        {ev.sub_type ? ` · ${ev.sub_type}` : ''} · {formatDate(ev.event_date)}
                      </p>
                    </div>
                    <button
                      type="button"
                      className="btn btn-danger btn-sm"
                      onClick={(e) => {
                        e.stopPropagation();
                        deleteEvent(ev);
                      }}
                    >
                      Delete
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="card">
            {!detail && <div className="empty">Select an event to manage todos, payments & guests</div>}
            {detail && (
              <>
                <div className="flex-between">
                  <div>
                    <h3>{detail.name}</h3>
                    <p className="muted">
                      {detail.event_type}
                      {detail.sub_type ? ` · ${detail.sub_type}` : ''} · {detail.location || 'No location'}
                    </p>
                  </div>
                  <span className="badge warning">{detail.status}</span>
                </div>

                <div className="grid grid-3" style={{ margin: '1rem 0' }}>
                  <div>
                    <p className="muted">Planned</p>
                    <strong>{formatCurrency(detail.summary?.planned)}</strong>
                  </div>
                  <div>
                    <p className="muted">Token paid</p>
                    <strong>{formatCurrency(detail.summary?.paid)}</strong>
                  </div>
                  <div>
                    <p className="muted">Remaining</p>
                    <strong>{formatCurrency(detail.summary?.remaining)}</strong>
                  </div>
                </div>
                <div className="progress-bar" style={{ marginBottom: '1rem' }}>
                  <span
                    style={{
                      width: `${
                        detail.summary?.planned
                          ? Math.min(100, (detail.summary.paid / detail.summary.planned) * 100)
                          : 0
                      }%`,
                    }}
                  />
                </div>

                <div className="grid grid-2" style={{ marginBottom: '1rem' }}>
                  <div>
                    <h4 style={{ marginBottom: '0.5rem' }}>Budget by category</h4>
                    <PieChart labels={Object.keys(byCat)} values={Object.values(byCat)} doughnut />
                  </div>
                  <div>
                    <h4 style={{ marginBottom: '0.5rem' }}>Paid vs remaining</h4>
                    <BarChart
                      labels={['Paid', 'Remaining']}
                      values={[detail.summary?.paid || 0, detail.summary?.remaining || 0]}
                    />
                  </div>
                </div>

                <h4 style={{ marginBottom: '0.5rem' }}>
                  Todo / bookings ({detail.summary?.itemsDone}/{detail.summary?.itemsTotal} done)
                </h4>
                <div className="table-wrap">
                  <table className="data-table">
                    <thead>
                      <tr>
                        <th>Done</th>
                        <th>Task</th>
                        <th>Vendor</th>
                        <th>Planned</th>
                        <th>Token</th>
                        <th>Left</th>
                        <th />
                      </tr>
                    </thead>
                    <tbody>
                      {items.map((it) => (
                        <tr key={it.id}>
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
                          <td>
                            <input
                              style={{ width: 100, background: 'transparent', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 6, padding: 4 }}
                              defaultValue={it.vendor_name || ''}
                              onBlur={(e) => updateItem(it, { vendor_name: e.target.value })}
                              placeholder="Vendor"
                            />
                          </td>
                          <td>
                            <input
                              type="number"
                              style={{ width: 80, background: 'transparent', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 6, padding: 4 }}
                              defaultValue={it.planned_amount}
                              onBlur={(e) => updateItem(it, { planned_amount: Number(e.target.value) })}
                            />
                          </td>
                          <td>
                            <input
                              type="number"
                              style={{ width: 80, background: 'transparent', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 6, padding: 4 }}
                              defaultValue={it.token_paid}
                              onBlur={(e) => updateItem(it, { token_paid: Number(e.target.value) })}
                            />
                          </td>
                          <td>{formatCurrency(it.remaining_amount)}</td>
                          <td>
                            <button type="button" className="btn btn-danger btn-sm" onClick={() => deleteItem(it)}>
                              Del
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>

                <form onSubmit={addItem} className="form-grid" style={{ marginTop: '1rem' }}>
                  <div className="field">
                    <label>New task</label>
                    <input
                      required
                      value={itemForm.title}
                      onChange={(e) => setItemForm({ ...itemForm, title: e.target.value })}
                    />
                  </div>
                  <div className="field">
                    <label>Category</label>
                    <input
                      value={itemForm.category}
                      onChange={(e) => setItemForm({ ...itemForm, category: e.target.value })}
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
                      Add task
                    </button>
                  </div>
                </form>

                <h4 style={{ margin: '1.25rem 0 0.5rem' }}>
                  Guest list · {detail.summary?.guestCount || 0} people
                </h4>
                <div className="table-wrap">
                  <table className="data-table">
                    <thead>
                      <tr>
                        <th>Name</th>
                        <th>Side</th>
                        <th>Count</th>
                        <th>RSVP</th>
                        <th />
                      </tr>
                    </thead>
                    <tbody>
                      {guests.map((g) => (
                        <tr key={g.id}>
                          <td>{g.name}</td>
                          <td>{g.side || '—'}</td>
                          <td>{g.count}</td>
                          <td>
                            <span className="badge">{g.rsvp}</span>
                          </td>
                          <td>
                            <button type="button" className="btn btn-danger btn-sm" onClick={() => deleteGuest(g)}>
                              Del
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
                <form onSubmit={addGuest} className="form-grid" style={{ marginTop: '0.75rem' }}>
                  <div className="field">
                    <label>Guest name</label>
                    <input
                      required
                      value={guestForm.name}
                      onChange={(e) => setGuestForm({ ...guestForm, name: e.target.value })}
                    />
                  </div>
                  <div className="field">
                    <label>Side</label>
                    <input
                      placeholder="Bride / Groom / Friend"
                      value={guestForm.side}
                      onChange={(e) => setGuestForm({ ...guestForm, side: e.target.value })}
                    />
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
                      <option value="pending">Pending</option>
                      <option value="yes">Yes</option>
                      <option value="no">No</option>
                      <option value="maybe">Maybe</option>
                    </select>
                  </div>
                  <div className="form-actions" style={{ alignItems: 'end' }}>
                    <button className="btn btn-primary" type="submit">
                      Add guest
                    </button>
                  </div>
                </form>
              </>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
