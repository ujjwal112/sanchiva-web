import { useEffect, useState } from 'react';
import { Link, Navigate, useNavigate } from 'react-router-dom';
import Logo from '../components/Logo';
import { useAuth } from '../auth/AuthContext';
import { API_ORIGIN } from '../api';

export default function Signup() {
  const { isAuthenticated, loading, loginWithProvider, registerWithPassword } = useAuth();
  const navigate = useNavigate();
  const [googleEnabled, setGoogleEnabled] = useState(false);
  const [message, setMessage] = useState('');
  const [submitting, setSubmitting] = useState(false);
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
        setMessage('Could not reach auth server. Wait for the site to wake up and try again.');
      });
  }, []);

  if (!loading && isAuthenticated) return <Navigate to="/dashboard" replace />;

  const set = (key) => (e) => setForm((f) => ({ ...f, [key]: e.target.value }));

  const onGoogle = () => {
    setMessage('');
    if (!googleEnabled) {
      setMessage(
        'Google signup is not configured yet. Use email & password, or add Google OAuth on the server (see AUTH_SETUP.md).'
      );
      return;
    }
    loginWithProvider('google');
  };

  const onSubmit = async (e) => {
    e.preventDefault();
    setMessage('');
    if (!form.name.trim()) {
      setMessage('Please enter your name');
      return;
    }
    if (!form.email.trim()) {
      setMessage('Please enter your email');
      return;
    }
    if (form.password.length < 8) {
      setMessage('Password must be at least 8 characters');
      return;
    }
    if (form.password !== form.confirm_password) {
      setMessage('Password and confirm password do not match');
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
      setMessage(err.message || 'Signup failed');
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
          <Logo size={64} />
          <h1>Create account</h1>
        </div>
        <p className="muted login-sub">Sign up with Google or email &amp; password.</p>

        {message && <div className="login-error">{message}</div>}

        <div className="login-buttons">
          <button type="button" className="btn login-btn login-google" onClick={onGoogle}>
            <span className="login-btn-icon">G</span>
            Sign up with Google
          </button>

          <div className="login-divider">
            <span>or email</span>
          </div>
        </div>

        <form className="auth-form" onSubmit={onSubmit}>
          <div className="field">
            <label htmlFor="signup-name">Name</label>
            <input
              id="signup-name"
              autoComplete="name"
              required
              value={form.name}
              onChange={set('name')}
              placeholder="Your name"
            />
          </div>
          <div className="field">
            <label htmlFor="signup-email">Email</label>
            <input
              id="signup-email"
              type="email"
              autoComplete="email"
              required
              value={form.email}
              onChange={set('email')}
              placeholder="you@example.com"
            />
          </div>
          <div className="field">
            <label htmlFor="signup-password">Password</label>
            <input
              id="signup-password"
              type="password"
              autoComplete="new-password"
              required
              minLength={8}
              value={form.password}
              onChange={set('password')}
              placeholder="At least 8 characters"
            />
          </div>
          <div className="field">
            <label htmlFor="signup-confirm">Confirm password</label>
            <input
              id="signup-confirm"
              type="password"
              autoComplete="new-password"
              required
              minLength={8}
              value={form.confirm_password}
              onChange={set('confirm_password')}
              placeholder="Re-enter password"
            />
          </div>
          <button type="submit" className="btn btn-primary login-btn" disabled={submitting}>
            {submitting ? 'Creating account…' : 'Create account'}
          </button>
        </form>

        <p className="auth-switch muted">
          Already have an account? <Link to="/login">Login</Link>
        </p>
      </div>
    </div>
  );
}
