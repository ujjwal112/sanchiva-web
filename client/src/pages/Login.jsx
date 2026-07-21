import { useEffect, useState } from 'react';
import { Link, Navigate, useNavigate, useSearchParams } from 'react-router-dom';
import Logo from '../components/Logo';
import { useAuth } from '../auth/AuthContext';
import { API_ORIGIN } from '../api';

export default function Login() {
  const { isAuthenticated, loading, loginWithProvider, loginAsGuest, loginWithPassword } = useAuth();
  const [params] = useSearchParams();
  const navigate = useNavigate();
  const error = params.get('error');
  const [googleEnabled, setGoogleEnabled] = useState(false);
  const [guestLoading, setGuestLoading] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [message, setMessage] = useState('');
  const [form, setForm] = useState({ email: '', password: '' });

  useEffect(() => {
    fetch(`${API_ORIGIN}/api/auth/providers`)
      .then((r) => r.json())
      .then((data) => setGoogleEnabled(!!data.google))
      .catch(() => {
        setMessage('Could not reach auth server. Try Guest login or wait for the site to wake up.');
      });
  }, []);

  useEffect(() => {
    if (error) setMessage('Login failed. Please try again.');
  }, [error]);

  if (!loading && isAuthenticated) return <Navigate to="/dashboard" replace />;

  const set = (key) => (e) => setForm((f) => ({ ...f, [key]: e.target.value }));

  const onGoogle = () => {
    setMessage('');
    if (!googleEnabled) {
      setMessage(
        'Google login is not configured yet. Use email login, Guest, or add GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET on Render (see AUTH_SETUP.md).'
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
      setMessage(e.message || 'Guest login failed');
    } finally {
      setGuestLoading(false);
    }
  };

  const onSubmit = async (e) => {
    e.preventDefault();
    setMessage('');
    if (!form.email.trim() || !form.password) {
      setMessage('Enter email and password');
      return;
    }
    setSubmitting(true);
    try {
      await loginWithPassword({
        email: form.email.trim(),
        password: form.password,
      });
      navigate('/dashboard', { replace: true });
    } catch (err) {
      setMessage(err.message || 'Login failed');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="login-page">
      <div className="login-card card auth-card-wide">
        <Link to="/" className="login-back-link">
          ← Back to home
        </Link>
        <div className="login-brand">
          <Logo size={72} />
          <h1>Sanchiva</h1>
        </div>

        <p className="muted login-sub">Login with Google or your email &amp; password.</p>

        {message && <div className="login-error">{message}</div>}

        <div className="login-buttons">
          <button type="button" className="btn login-btn login-google" onClick={onGoogle}>
            <span className="login-btn-icon">G</span>
            Continue with Google
          </button>

          <div className="login-divider">
            <span>or email</span>
          </div>
        </div>

        <form className="auth-form" onSubmit={onSubmit}>
          <div className="field">
            <label htmlFor="login-email">Email</label>
            <input
              id="login-email"
              type="email"
              autoComplete="email"
              required
              value={form.email}
              onChange={set('email')}
              placeholder="you@example.com"
            />
          </div>
          <div className="field">
            <label htmlFor="login-password">Password</label>
            <input
              id="login-password"
              type="password"
              autoComplete="current-password"
              required
              value={form.password}
              onChange={set('password')}
              placeholder="Your password"
            />
          </div>
          <button type="submit" className="btn btn-primary login-btn" disabled={submitting}>
            {submitting ? 'Signing in…' : 'Login'}
          </button>
        </form>

        <div className="login-divider" style={{ marginTop: '1rem' }}>
          <span>or</span>
        </div>

        <button type="button" className="btn login-btn login-guest" disabled={guestLoading} onClick={onGuest}>
          <span className="login-btn-icon">👤</span>
          {guestLoading ? 'Starting guest session…' : 'Continue as Guest'}
        </button>

        <p className="auth-switch muted">
          New here? <Link to="/signup">Create an account</Link>
        </p>
      </div>
    </div>
  );
}
