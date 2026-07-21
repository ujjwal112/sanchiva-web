import { useEffect, useState } from 'react';
import { Link, Navigate, useNavigate, useSearchParams } from 'react-router-dom';
import Logo from '../components/Logo';
import { useAuth } from '../auth/AuthContext';
import { API_ORIGIN } from '../api';

export default function Login() {
  const { isAuthenticated, loading, loginWithProvider, loginAsGuest } = useAuth();
  const [params] = useSearchParams();
  const navigate = useNavigate();
  const error = params.get('error');
  const [googleEnabled, setGoogleEnabled] = useState(false);
  const [guestLoading, setGuestLoading] = useState(false);
  const [message, setMessage] = useState('');

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
        'Google login is not configured yet. Use Continue as Guest, or add GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET on Render (see AUTH_SETUP.md).'
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

  return (
    <div className="login-page">
      <div className="login-card card">
        <Link to="/" className="login-back-link">
          ← Back to home
        </Link>
        <div className="login-brand">
          <Logo size={72} />
          <h1>Sanchiva</h1>
        </div>

        <p className="muted login-sub">Sign in to access your world securely.</p>

        {message && <div className="login-error">{message}</div>}

        <div className="login-buttons">
          <button type="button" className="btn login-btn login-google" onClick={onGoogle}>
            <span className="login-btn-icon">G</span>
            Continue with Google
          </button>

          <div className="login-divider">
            <span>or</span>
          </div>

          <button type="button" className="btn login-btn login-guest" disabled={guestLoading} onClick={onGuest}>
            <span className="login-btn-icon">👤</span>
            {guestLoading ? 'Starting guest session…' : 'Continue as Guest'}
          </button>
        </div>
      </div>
    </div>
  );
}
