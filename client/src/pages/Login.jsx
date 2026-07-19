import { useEffect, useState } from 'react';
import { Navigate, useNavigate, useSearchParams } from 'react-router-dom';
import Logo from '../components/Logo';
import { useAuth } from '../auth/AuthContext';
import { API_ORIGIN } from '../api';

export default function Login() {
  const { isAuthenticated, loading, loginWithProvider, loginAsGuest } = useAuth();
  const [params] = useSearchParams();
  const navigate = useNavigate();
  const error = params.get('error');
  const [providers, setProviders] = useState({
    google: true,
    facebook: true,
    microsoft: true,
    guest: true,
  });
  const [guestLoading, setGuestLoading] = useState(false);
  const [guestError, setGuestError] = useState('');

  useEffect(() => {
    fetch(`${API_ORIGIN}/api/auth/providers`)
      .then((r) => r.json())
      .then(setProviders)
      .catch(() => {});
  }, []);

  if (!loading && isAuthenticated) return <Navigate to="/" replace />;

  const onGuest = async () => {
    setGuestError('');
    setGuestLoading(true);
    try {
      await loginAsGuest();
      navigate('/', { replace: true });
    } catch (e) {
      setGuestError(e.message || 'Guest login failed');
    } finally {
      setGuestLoading(false);
    }
  };

  return (
    <div className="login-page">
      <div className="login-card card">
        <div className="login-brand">
          <Logo size={72} />
          <h1>Sanchiva</h1>
          <p className="login-motto">Everything that matters — one place.</p>
        </div>

        <p className="muted login-sub">Sign in to access your personal finance data securely.</p>

        {(error || guestError) && (
          <div className="login-error">
            {guestError || `Login failed (${error}). Please try again or check OAuth app settings.`}
          </div>
        )}

        <div className="login-buttons">
          <button
            type="button"
            className="btn login-btn login-google"
            disabled={!providers.google}
            onClick={() => loginWithProvider('google')}
          >
            <span className="login-btn-icon">G</span>
            Continue with Google
          </button>
          <button
            type="button"
            className="btn login-btn login-facebook"
            disabled={!providers.facebook}
            onClick={() => loginWithProvider('facebook')}
          >
            <span className="login-btn-icon">f</span>
            Continue with Facebook
          </button>
          <button
            type="button"
            className="btn login-btn login-microsoft"
            disabled={!providers.microsoft}
            onClick={() => loginWithProvider('microsoft')}
          >
            <span className="login-btn-icon">⊞</span>
            Continue with Microsoft
          </button>

          <div className="login-divider">
            <span>or</span>
          </div>

          <button
            type="button"
            className="btn login-btn login-guest"
            disabled={guestLoading}
            onClick={onGuest}
          >
            <span className="login-btn-icon">👤</span>
            {guestLoading ? 'Starting guest session…' : 'Continue as Guest'}
          </button>
        </div>

        <p className="muted login-hint">
          Guest mode lets you try all features. When you log out, all guest data from that session is
          deleted permanently.
        </p>

        {(!providers.google || !providers.facebook || !providers.microsoft) && (
          <p className="muted login-hint">
            Some social providers are not configured yet. You can still use Guest login anytime.
          </p>
        )}

        <p className="muted login-footer">
          Developed by Ujjwal Gupta · Access & refresh token sessions
        </p>
      </div>
    </div>
  );
}
