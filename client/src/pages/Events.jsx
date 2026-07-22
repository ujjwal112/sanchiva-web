import { useCallback, useEffect, useRef, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { api, formatCurrency, formatDate, formatEventStyleLabel } from '../api';
import { Tabs, DateInput, GlassSelect, useToast } from '../components/ui';

const EVENT_TYPES = [
  { id: 'wedding', label: 'Wedding', icon: '💍' },
  { id: 'birthday', label: 'Birthday', icon: '🎂' },
  { id: 'anniversary', label: 'Anniversary', icon: '💞' },
  { id: 'housewarming', label: 'Housewarming', icon: '🏠' },
  { id: 'corporate', label: 'Corporate', icon: '🏢' },
  { id: 'other', label: 'Other event', icon: '✦' },
];

function eventTypeIcon(type) {
  const t = String(type || '').toLowerCase();
  return EVENT_TYPES.find((x) => x.id === t)?.icon || '✦';
}

export default function Events() {
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const initialTab = searchParams.get('tab') === 'list' ? 'list' : 'create';
  const [tab, setTab] = useState(initialTab);
  const [events, setEvents] = useState([]);

  const [step, setStep] = useState('pick');
  const [eventType, setEventType] = useState(null);
  const [questions, setQuestions] = useState([]);
  const [intro, setIntro] = useState('');
  const [qIndex, setQIndex] = useState(0);
  const [answers, setAnswers] = useState({});
  const [currentAnswer, setCurrentAnswer] = useState('');
  const [multiSel, setMultiSel] = useState([]);
  const [customCeremony, setCustomCeremony] = useState('');
  const [customCeremonies, setCustomCeremonies] = useState([]);
  const [chat, setChat] = useState([]);
  const [creating, setCreating] = useState(false);

  const { show, Toast } = useToast();
  const wizardChatRef = useRef(null);
  const wizardQuestionRef = useRef(null);
  const wizardAnswerRef = useRef(null);
  const answerInputRef = useRef(null);

  const loadEvents = useCallback(() => {
    api.get('/events').then(setEvents).catch((e) => show(e.message, 'error'));
  }, []);

  useEffect(() => {
    loadEvents();
  }, [loadEvents]);

  useEffect(() => {
    const t = searchParams.get('tab') === 'list' ? 'list' : 'create';
    setTab(t);
  }, [searchParams]);

  const changeTab = (id) => {
    setTab(id);
    setSearchParams(id === 'list' ? { tab: 'list' } : {});
  };

  // When question changes: only apply default for THIS question
  useEffect(() => {
    if (step !== 'questions') return;
    const q = questions[qIndex];
    if (!q) return;
    if (q.type === 'multiselect') {
      setCurrentAnswer('');
      setMultiSel([]);
      setCustomCeremony('');
      setCustomCeremonies([]);
    } else if (q.default != null && q.default !== '') {
      setCurrentAnswer(String(q.default));
    } else {
      setCurrentAnswer('');
    }
  }, [qIndex, step, questions]);

  useEffect(() => {
    if (step !== 'questions') return;
    const q = questions[qIndex];
    const t = setTimeout(() => {
      if (wizardChatRef.current) {
        wizardChatRef.current.scrollTop = wizardChatRef.current.scrollHeight;
      }
      wizardQuestionRef.current?.scrollIntoView({ behavior: 'smooth', block: 'center' });
      wizardAnswerRef.current?.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
      if (q?.type !== 'date') {
        answerInputRef.current?.focus?.();
      }
    }, 80);
    return () => clearTimeout(t);
  }, [qIndex, step, chat.length, questions]);

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
      setCustomCeremony('');
      setCustomCeremonies([]);
      setChat([{ role: 'ai', text: data.intro }]);
      setStep('questions');
    } catch (e) {
      show(e.message, 'error');
    }
  };

  const currentQ = questions[qIndex];
  const multiOptions = currentQ?.options || [];
  const allowCustomMulti =
    currentQ?.type === 'multiselect' &&
    (currentQ.allowCustom || multiOptions.includes('Other') || currentQ.id === 'ceremonies');
  const otherSelected = multiSel.includes('Other');

  const addCustomCeremony = () => {
    const name = customCeremony.trim();
    if (!name) {
      show('Enter a ceremony name', 'error');
      return;
    }
    if (name.toLowerCase() === 'other') {
      show('Please enter a real ceremony name', 'error');
      return;
    }
    const exists =
      multiOptions.some((o) => o.toLowerCase() === name.toLowerCase() && o !== 'Other') ||
      customCeremonies.some((c) => c.toLowerCase() === name.toLowerCase());
    if (exists) {
      show('That ceremony is already in the list', 'error');
      return;
    }
    setCustomCeremonies((list) => [...list, name]);
    setCustomCeremony('');
    if (!multiSel.includes('Other')) {
      setMultiSel((s) => [...s, 'Other']);
    }
  };

  const removeCustomCeremony = (name) => {
    setCustomCeremonies((list) => list.filter((c) => c !== name));
  };

  const goNextQuestion = () => {
    setMultiSel([]);
    setCustomCeremony('');
    setCustomCeremonies([]);
    setQIndex((i) => i + 1);
  };

  const pushAnswer = async () => {
    if (!currentQ) return;
    let value = currentAnswer;
    if (currentQ.type === 'multiselect') {
      const selectedBuiltIn = multiSel.filter((x) => x !== 'Other');
      value = [...selectedBuiltIn, ...customCeremonies];
      if (otherSelected && !customCeremonies.length && allowCustomMulti) {
        show('Add your custom ceremony name, or unselect Other', 'error');
        return;
      }
    }
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
      { role: 'user', text: Array.isArray(value) ? value.join(', ') : String(value || '-') },
    ]);
    setAnswers(nextAnswers);
    setMultiSel([]);
    setCustomCeremony('');
    setCustomCeremonies([]);

    // After ceremony multi-select: ask for each ceremony's date
    if (currentQ.id === 'ceremonies' && Array.isArray(value) && value.length) {
      const names = value.filter((n) => n && String(n).toLowerCase() !== 'other');
      setQuestions((prev) => {
        const cleaned = prev.filter((q) => !String(q.id).startsWith('ceremony_date_'));
        const idx = cleaned.findIndex((q) => q.id === 'ceremonies');
        if (idx < 0) return cleaned;
        const dateQs = names.map((ceremonyName, i) => ({
          id: `ceremony_date_${i}`,
          label: `When is the ${ceremonyName} ceremony?`,
          type: 'date',
          required: true,
          ceremonyName,
        }));
        const next = [...cleaned];
        next.splice(idx + 1, 0, ...dateQs);
        return next;
      });
      setQIndex(qIndex + 1);
      return;
    }

    // Compute remaining questions (questions state may still be pre-inject for length)
    if (qIndex + 1 < questions.length) {
      setQIndex(qIndex + 1);
    } else {
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
            text: `All set! I created “${created.name}” with ${created.items?.length || 0} planned tasks. Open it under My Events to view details.`,
          },
        ]);
        loadEvents();
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

  const deleteEvent = async (ev) => {
    if (!confirm(`Delete event “${ev.name}”?`)) return;
    await api.del(`/events/${ev.id}`);
    loadEvents();
    show('Event deleted');
  };

  return (
    <div className="events-page">
      {Toast}
      <Tabs
        tabs={[
          { id: 'create', label: 'Create Event' },
          { id: 'list', label: 'My Events' },
        ]}
        active={tab}
        onChange={changeTab}
      />

      {tab === 'create' && (
        <div className="card wizard">
          {step === 'pick' && (
            <>
              <h3>What are we planning?</h3>
              <p className="muted" style={{ marginBottom: '1rem' }}>
                Pick a type and I will ask the right questions, then build a checklist with venues, vendors,
                budgets and guest tracking.
              </p>
              <div className="grid grid-3">
                {EVENT_TYPES.map((t) => (
                  <button
                    key={t.id}
                    type="button"
                    className="card event-type-card"
                    onClick={() => startWizard(t.id)}
                  >
                    <div className="event-type-icon">{t.icon}</div>
                    <h3>{t.label}</h3>
                    <p className="muted">Smart questionnaire + todo tracker</p>
                  </button>
                ))}
              </div>
            </>
          )}

          {step === 'questions' && currentQ && (
            <>
              <div className="flex-between wizard-header">
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
              <div className="progress-bar wizard-progress">
                <span style={{ width: `${((qIndex + 1) / questions.length) * 100}%` }} />
              </div>

              <div className="wizard-chat" ref={wizardChatRef}>
                {chat.map((m, i) => (
                  <div key={i} className={`bubble ${m.role === 'ai' ? 'ai' : 'user'}`}>
                    {m.text}
                  </div>
                ))}
                <div className="bubble ai wizard-current-q" ref={wizardQuestionRef}>
                  <strong>{currentQ.label}</strong>
                  {currentQ.required && (
                    <span className="badge" style={{ marginLeft: 8 }}>
                      required
                    </span>
                  )}
                </div>
              </div>

              <div className="wizard-answer-panel card" ref={wizardAnswerRef}>
                {currentQ.type === 'select' && (
                  <div className="field">
                    <GlassSelect
                      value={currentAnswer}
                      onChange={setCurrentAnswer}
                      placeholder="Select…"
                      options={currentQ.options || []}
                      aria-label={currentQ.label || 'Select'}
                    />
                  </div>
                )}
                {currentQ.type === 'multiselect' && (
                  <div className="multi-select-block">
                    <div className="checkbox-row">
                      {multiOptions.map((o) => {
                        const on = multiSel.includes(o);
                        return (
                          <button
                            key={o}
                            type="button"
                            className={`chip ${on ? 'selected' : ''}`}
                            onClick={() => {
                              setMultiSel((s) => {
                                if (on) {
                                  const next = s.filter((x) => x !== o);
                                  if (o === 'Other') {
                                    setCustomCeremony('');
                                    setCustomCeremonies([]);
                                  }
                                  return next;
                                }
                                return [...s, o];
                              });
                            }}
                          >
                            {o}
                          </button>
                        );
                      })}
                    </div>

                    {allowCustomMulti && otherSelected && (
                      <div className="custom-ceremony-box">
                        <div className="custom-ceremony-row">
                          <div className="field" style={{ flex: 1, marginBottom: 0 }}>
                            <label>Custom ceremony name</label>
                            <input
                              value={customCeremony}
                              onChange={(e) => setCustomCeremony(e.target.value)}
                              placeholder="Enter ceremony name"
                              autoComplete="off"
                              onKeyDown={(e) => {
                                if (e.key === 'Enter') {
                                  e.preventDefault();
                                  addCustomCeremony();
                                }
                              }}
                            />
                          </div>
                          <button type="button" className="btn btn-ghost" onClick={addCustomCeremony}>
                            Add
                          </button>
                        </div>
                        {!!customCeremonies.length && (
                          <div className="checkbox-row" style={{ marginTop: '0.65rem' }}>
                            {customCeremonies.map((c) => (
                              <button
                                key={c}
                                type="button"
                                className="chip selected custom-chip"
                                onClick={() => removeCustomCeremony(c)}
                                title="Click to remove"
                              >
                                {c} ×
                              </button>
                            ))}
                          </div>
                        )}
                      </div>
                    )}
                  </div>
                )}
                {currentQ.type === 'date' && (
                  <div className="field field-date">
                    <DateInput
                      ref={answerInputRef}
                      value={currentAnswer}
                      onChange={(e) => setCurrentAnswer(e.target.value)}
                      placeholder="Select a date"
                      onKeyDown={(e) => e.key === 'Enter' && pushAnswer()}
                    />
                  </div>
                )}
                {['text', 'number'].includes(currentQ.type) && (
                  <div className="field">
                    <input
                      ref={answerInputRef}
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
                    <textarea
                      ref={answerInputRef}
                      value={currentAnswer}
                      onChange={(e) => setCurrentAnswer(e.target.value)}
                    />
                  </div>
                )}
                <div className="form-actions" style={{ marginTop: '0.75rem' }}>
                  <button type="button" className="btn btn-primary" onClick={pushAnswer} disabled={creating}>
                    {qIndex + 1 >= questions.length ? (creating ? 'Creating…' : 'Create event') : 'Next'}
                  </button>
                  {!currentQ.required && qIndex + 1 < questions.length && (
                    <button type="button" className="btn btn-ghost" onClick={goNextQuestion}>
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
                <button type="button" className="btn btn-primary" onClick={() => changeTab('list')}>
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
        <section className="card events-list-only">
          <h3>Your events</h3>
          <p className="muted" style={{ marginBottom: '1rem' }}>
            All events you created. Click <strong>View</strong> to open full event details.
          </p>
          {!events.length && (
            <div className="empty">
              <span className="emoji">✦</span>
              No events yet. Create one with the Create Event tab.
            </div>
          )}
          <div className="events-list-items events-list-items-wide">
            {events.map((ev) => (
              <div key={ev.id} className="event-list-item">
                <div className="event-list-item-icon" aria-hidden>
                  {eventTypeIcon(ev.event_type)}
                </div>
                <div className="event-list-item-main">
                  <strong>{ev.name}</strong>
                  <span className="event-list-badge">
                    {formatEventStyleLabel(ev.event_type, ev.sub_type)}
                  </span>
                  <div className="event-list-item-meta muted">
                    {ev.event_date ? <span>📅 {formatDate(ev.event_date)}</span> : null}
                    {ev.location ? <span>📍 {ev.location}</span> : null}
                    {ev.budget != null && Number(ev.budget) > 0 ? (
                      <span>₹ {formatCurrency(ev.budget)}</span>
                    ) : null}
                  </div>
                </div>
                <div className="event-list-actions">
                  <button
                    type="button"
                    className="btn btn-primary btn-sm"
                    onClick={() => navigate(`/events/${ev.id}`)}
                  >
                    View
                  </button>
                  <button type="button" className="btn btn-danger btn-sm" onClick={() => deleteEvent(ev)}>
                    Delete
                  </button>
                </div>
              </div>
            ))}
          </div>
        </section>
      )}
    </div>
  );
}
