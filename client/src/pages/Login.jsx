import { useEffect, useState } from 'react';
import { Link, Navigate, useNavigate, useSearchParams } from 'react-router-dom';
import Logo from '../components/Logo';
import { PasswordInput } from '../components/ui';
import { useAuth } from '../auth/AuthContext';
import { API_ORIGIN } from '../api';

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
      <div className="login-shell">
        <Link to="/" className="login-back-link">
          ← Back to home
        </Link>

        <div className="login-heading-block">
          <Logo size={40} className="login-heading-logo" />
          <h1 className="login-title">
            {step === 'email' ? 'Log in to your account' : 'Enter your password'}
          </h1>
        </div>

        <div className="login-card">
          {message && <div className="login-error">{message}</div>}

          {step === 'email' && (
            <>
              <form className="auth-form" onSubmit={onEmailContinue}>
                <div className="field">
                  <input
                    id="login-email"
                    type="email"
                    autoComplete="email"
                    required
                    autoFocus
                    aria-label="Email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="Enter your email"
                  />
                </div>
                <button type="submit" className="btn login-btn login-btn-continue">
                  Continue
                </button>
              </form>

              <div className="login-divider">
                <span>OR</span>
              </div>

              <div className="login-buttons">
                <button type="button" className="btn login-btn login-btn-outline login-google" onClick={onGoogle}>
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
                  <PasswordInput
                    id="login-password"
                    autoComplete="current-password"
                    required
                    autoFocus
                    aria-label="Password"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="Password"
                  />
                </div>
                <button type="submit" className="btn login-btn login-btn-continue" disabled={submitting}>
                  {submitting ? 'Signing in…' : 'Log in'}
                </button>
              </form>

              <p className="auth-switch">
                <button type="button" className="auth-text-btn" onClick={backToEmail}>
                  ← Back to email
                </button>
              </p>
            </>
          )}
        </div>

        <p className="auth-switch login-footer-switch">
          New here? <Link to="/signup">Create an account</Link>
        </p>
      </div>
    </div>
  );
}
