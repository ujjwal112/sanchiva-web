import { useEffect, useState } from 'react';
import { Link, Navigate, useNavigate } from 'react-router-dom';
import Logo from '../components/Logo';
import { PasswordInput } from '../components/ui';
import { useAuth } from '../auth/AuthContext';
import { API_ORIGIN } from '../api';

const FEATURES = [
  'Dashboard with spends, EMIs, income and assets at a glance',
  'Daily expense tracking with categories and exports',
  'Bank loans and credit card EMIs under control',
  'Income, FDs, gold, and money you have given',
  'Weddings and life events with budgets, todos, and guests',
];

function GoogleIcon() {
  return (
    <svg className="login-provider-icon" viewBox="0 0 24 24" width="20" height="20" aria-hidden>
      <path
        fill="#4285F4"
        d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
      />
      <path
        fill="#34A853"
        d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
      />
      <path
        fill="#FBBC05"
        d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
      />
      <path
        fill="#EA4335"
        d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
      />
    </svg>
  );
}

function providerLabel(provider) {
  if (provider === 'google') return 'Google';
  if (provider === 'local') return 'email and password';
  if (provider === 'microsoft') return 'Microsoft';
  if (provider === 'facebook') return 'Facebook';
  return provider || 'another method';
}

export default function Signup() {
  const { isAuthenticated, loading, registerWithPassword, loginWithProvider, loginAsGuest } =
    useAuth();
  const navigate = useNavigate();
  const [message, setMessage] = useState('');
  const [messageTone, setMessageTone] = useState('error'); // error | info
  const [submitting, setSubmitting] = useState(false);
  const [checkingEmail, setCheckingEmail] = useState(false);
  const [guestLoading, setGuestLoading] = useState(false);
  const [googleEnabled, setGoogleEnabled] = useState(false);
  /** email | details */
  const [step, setStep] = useState('email');
  const [form, setForm] = useState({
    name: '',
    email: '',
    password: '',
    confirm_password: '',
  });

  useEffect(() => {
    fetch(`${API_ORIGIN}/api/auth/providers`)
      .then((r) => r.json())
      .then((data) => setGoogleEnabled(!!data.google))
      .catch(() => {
        /* keep default */
      });
  }, []);

  if (!loading && isAuthenticated) return <Navigate to="/dashboard" replace />;

  const set = (key) => (e) => setForm((f) => ({ ...f, [key]: e.target.value }));

  const showError = (text) => {
    setMessageTone('error');
    setMessage(text);
  };

  const showInfo = (text) => {
    setMessageTone('info');
    setMessage(text);
  };

  const backToEmail = () => {
    setStep('email');
    setMessage('');
    setForm((f) => ({ ...f, name: '', password: '', confirm_password: '' }));
  };

  const onEmailContinue = async (e) => {
    e.preventDefault();
    setMessage('');
    const email = form.email.trim().toLowerCase();
    if (!email) {
      showError('Please enter your email');
      return;
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      showError('Enter a valid email address');
      return;
    }

    setCheckingEmail(true);
    try {
      const res = await fetch(`${API_ORIGIN}/api/auth/check-email`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) {
        showError(data.error || 'Could not check email');
        return;
      }

      setForm((f) => ({ ...f, email: data.email || email }));

      if (data.exists) {
        const provider = data.provider || 'local';
        if (provider === 'google') {
          showInfo(
            'This email is already registered with Google. Please use Continue with Google or log in.'
          );
        } else if (provider === 'local') {
          showInfo(
            'This email is already registered with email and password. Please log in instead.'
          );
        } else {
          showInfo(
            `This email is already registered with ${providerLabel(provider)}. Please log in instead.`
          );
        }
        return;
      }

      // New email: show name + password fields
      setStep('details');
      setMessage('');
    } catch {
      showError('Could not reach the server. Try again in a moment.');
    } finally {
      setCheckingEmail(false);
    }
  };

  const onSubmitDetails = async (e) => {
    e.preventDefault();
    setMessage('');
    if (!form.name.trim()) {
      showError('Please enter your name');
      return;
    }
    if (form.password.length < 8) {
      showError('Password must be at least 8 characters');
      return;
    }
    if (form.password !== form.confirm_password) {
      showError('Password and confirm password do not match');
      return;
    }
    setSubmitting(true);
    try {
      await registerWithPassword({
        name: form.name.trim(),
        email: form.email.trim(),
        password: form.password,
        confirm_password: form.confirm_password,
      });
      navigate('/dashboard', { replace: true });
    } catch (err) {
      showError(err.message || 'Signup failed');
    } finally {
      setSubmitting(false);
    }
  };

  const onGoogle = () => {
    setMessage('');
    if (!googleEnabled) {
      showError(
        'Google login is not configured yet. Use email signup, Guest, or add GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET on Render.'
      );
      return;
    }
    loginWithProvider('google');
  };

  const onGuest = async () => {
    setMessage('');
    setGuestLoading(true);
    try {
      await loginAsGuest();
      navigate('/dashboard', { replace: true });
    } catch (e) {
      showError(e.message || 'Guest login failed');
    } finally {
      setGuestLoading(false);
    }
  };

  return (
    <div className="signup-page">
      <div className="signup-split">
        {/* Left: signup form */}
        <section className="signup-form-pane">
          <div className="signup-form-inner">
            <Link to="/" className="login-back-link signup-back">
              ← Back to home
            </Link>

            <h1 className="signup-form-title">Create your free account</h1>
            <p className="signup-form-sub">
              {step === 'email'
                ? 'No credit card required. Start tracking anytime.'
                : 'Almost done. Add your name and a password.'}
            </p>

            {message && (
              <div className={`login-error${messageTone === 'info' ? ' login-error--info' : ''}`}>
                {message}
                {messageTone === 'info' && (
                  <p className="signup-existing-actions">
                    <Link to="/login">Go to Log in</Link>
                    {message.toLowerCase().includes('google') && (
                      <>
                        {' · '}
                        <button type="button" className="auth-text-btn" onClick={onGoogle}>
                          Continue with Google
                        </button>
                      </>
                    )}
                  </p>
                )}
              </div>
            )}

            {step === 'email' && (
              <>
                <form className="auth-form signup-form" onSubmit={onEmailContinue}>
                  <div className="field">
                    <input
                      id="signup-email"
                      type="email"
                      autoComplete="email"
                      required
                      autoFocus
                      aria-label="Email"
                      value={form.email}
                      onChange={set('email')}
                      placeholder="Enter your email"
                    />
                  </div>
                  <button
                    type="submit"
                    className="btn login-btn login-btn-continue"
                    disabled={checkingEmail}
                  >
                    {checkingEmail ? 'Checking…' : 'Continue with email'}
                  </button>
                </form>

                <div className="login-divider">
                  <span>OR</span>
                </div>

                <div className="login-buttons">
                  <button
                    type="button"
                    className="btn login-btn login-btn-outline login-google"
                    onClick={onGoogle}
                  >
                    <GoogleIcon />
                    Continue with Google
                  </button>
                  <button
                    type="button"
                    className="btn login-btn login-btn-outline login-guest"
                    disabled={guestLoading}
                    onClick={onGuest}
                  >
                    <span className="login-guest-icon" aria-hidden>
                      👤
                    </span>
                    {guestLoading ? 'Starting guest session…' : 'Continue as Guest'}
                  </button>
                </div>

                <p className="signup-hint">
                  Use Google or Guest for a faster start. Your data stays private.
                </p>
              </>
            )}

            {step === 'details' && (
              <>
                <div className="auth-email-chip signup-email-chip">
                  <span className="muted">Signing up as</span>
                  <strong>{form.email}</strong>
                  <button type="button" className="btn btn-ghost btn-sm" onClick={backToEmail}>
                    Change
                  </button>
                </div>

                <form className="auth-form signup-form" onSubmit={onSubmitDetails}>
                  <div className="field">
                    <input
                      id="signup-name"
                      autoComplete="name"
                      required
                      autoFocus
                      aria-label="Name"
                      value={form.name}
                      onChange={set('name')}
                      placeholder="Enter your name"
                    />
                  </div>
                  <div className="field">
                    <PasswordInput
                      id="signup-password"
                      autoComplete="new-password"
                      required
                      minLength={8}
                      aria-label="Password"
                      value={form.password}
                      onChange={set('password')}
                      placeholder="Password (min 8 characters)"
                    />
                  </div>
                  <div className="field">
                    <PasswordInput
                      id="signup-confirm"
                      autoComplete="new-password"
                      required
                      minLength={8}
                      aria-label="Confirm password"
                      value={form.confirm_password}
                      onChange={set('confirm_password')}
                      placeholder="Confirm password"
                    />
                  </div>
                  <button
                    type="submit"
                    className="btn login-btn login-btn-continue"
                    disabled={submitting}
                  >
                    {submitting ? 'Creating account…' : 'Create account'}
                  </button>
                </form>

                <p className="signup-hint">
                  <button type="button" className="auth-text-btn" onClick={backToEmail}>
                    ← Use a different email
                  </button>
                </p>
              </>
            )}

            <p className="signup-login-link">
              Already have an account?{' '}
              <Link to="/login">
                Log In <span aria-hidden>→</span>
              </Link>
            </p>
          </div>
        </section>

        {/* Right: product info */}
        <aside className="signup-info-pane" aria-label="Why Sanchiva">
          <div className="signup-info-inner">
            <span className="signup-info-badge">Free to start</span>
            <h2 className="signup-info-title">
              Everything that matters in one place for your money and moments
            </h2>
            <ul className="signup-info-list">
              {FEATURES.map((item) => (
                <li key={item}>
                  <span className="signup-check" aria-hidden>
                    ✓
                  </span>
                  <span>{item}</span>
                </li>
              ))}
            </ul>
            <p className="signup-info-foot">
              Join people who keep spends, loans, assets, and events organised with Sanchiva.
            </p>
            <div className="signup-info-brand">
              <Logo size={28} />
              <span>Sanchiva</span>
            </div>
          </div>
        </aside>
      </div>
    </div>
  );
}
