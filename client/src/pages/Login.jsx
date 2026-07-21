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
  /** email → password (custom login is two steps) */
  const [step, setStep] = useState('email');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

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

  const onEmailContinue = (e) => {
    e.preventDefault();
    setMessage('');
    const value = email.trim();
    if (!value) {
      setMessage('Please enter your email');
      return;
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) {
      setMessage('Enter a valid email address');
      return;
    }
    setEmail(value);
    setStep('password');
  };

  const backToEmail = () => {
    setMessage('');
    setPassword('');
    setStep('email');
  };

  const onPasswordSubmit = async (e) => {
    e.preventDefault();
    setMessage('');
    if (!password) {
      setMessage('Please enter your password');
      return;
    }
    setSubmitting(true);
    try {
      await loginWithPassword({
        email: email.trim(),
        password,
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

        <p className="muted login-sub">
          {step === 'email'
            ? 'Login with Google or enter your email to continue.'
            : 'Enter your password to sign in.'}
        </p>

        {message && <div className="login-error">{message}</div>}

        {step === 'email' && (
          <>
            <div className="login-buttons">
              <button type="button" className="btn login-btn login-google" onClick={onGoogle}>
                <span className="login-btn-icon">G</span>
                Continue with Google
              </button>

              <div className="login-divider">
                <span>or email</span>
              </div>
            </div>

            <form className="auth-form" onSubmit={onEmailContinue}>
              <div className="field">
                <label htmlFor="login-email">Email</label>
                <input
                  id="login-email"
                  type="email"
                  autoComplete="email"
                  required
                  autoFocus
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="you@example.com"
                />
              </div>
              <button type="submit" className="btn btn-primary login-btn">
                Continue
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
          </>
        )}

        {step === 'password' && (
          <>
            <div className="auth-email-chip">
              <span className="muted">Signing in as</span>
              <strong>{email}</strong>
              <button type="button" className="btn btn-ghost btn-sm" onClick={backToEmail}>
                Change
              </button>
            </div>

            <form className="auth-form" onSubmit={onPasswordSubmit}>
              <div className="field">
                <label htmlFor="login-password">Password</label>
                <input
                  id="login-password"
                  type="password"
                  autoComplete="current-password"
                  required
                  autoFocus
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="Your password"
                />
              </div>
              <button type="submit" className="btn btn-primary login-btn" disabled={submitting}>
                {submitting ? 'Signing in…' : 'Login'}
              </button>
            </form>

            <p className="auth-switch muted">
              <button type="button" className="auth-text-btn" onClick={backToEmail}>
                ← Back to email
              </button>
            </p>
          </>
        )}
      </div>
    </div>
  );
}
