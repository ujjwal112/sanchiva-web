import { useEffect, useState } from 'react';
import { Navigate, useNavigate, useSearchParams } from 'react-router-dom';
import Logo from '../components/Logo';
import { useAuth } from '../auth/AuthContext';
import { API_ORIGIN } from '../api';

const PROVIDER_LABELS = {
  google: 'Google',
  facebook: 'Facebook',
  microsoft: 'Microsoft',
};

export default function Login() {
  const { isAuthenticated, loading, loginWithProvider, loginAsGuest } = useAuth();
  const [params] = useSearchParams();
  const navigate = useNavigate();
  const error = params.get('error');
  const [providers, setProviders] = useState({
    google: false,
    facebook: false,
    microsoft: false,
    guest: true,
  });
  const [guestLoading, setGuestLoading] = useState(false);
  const [message, setMessage] = useState('');

  useEffect(() => {
    fetch(`${API_ORIGIN}/api/auth/providers`)
      .then((r) => r.json())
      .then((data) => setProviders({ google: false, facebook: false, microsoft: false, guest: true, ...data }))
      .catch(() => {
        setMessage('Could not reach auth server. Try Guest login or wait for the site to wake up.');
      });
  }, []);

  useEffect(() => {
    if (error) setMessage('Login failed. Please try again.');
  }, [error]);

  if (!loading && isAuthenticated) return <Navigate to="/" replace />;

  const onSocial = (provider) => {
    setMessage('');
    if (!providers[provider]) {
      setMessage(
        `${PROVIDER_LABELS[provider]} login is not configured on the server yet. Use Continue as Guest, or add ${PROVIDER_LABELS[provider]} OAuth keys in Render environment variables (see AUTH_SETUP.md).`
      );
      return;
    }
    loginWithProvider(provider);
  };

  const onGuest = async () => {
    setMessage('');
    setGuestLoading(true);
    try {
      await loginAsGuest();
      navigate('/', { replace: true });
    } catch (e) {
      setMessage(e.message || 'Guest login failed');
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
        </div>

        <p className="muted login-sub">Sign in to access your world securely.</p>

        {message && <div className="login-error">{message}</div>}

        <div className="login-buttons">
          <button type="button" className="btn login-btn login-google" onClick={() => onSocial('google')}>
            <span className="login-btn-icon">G</span>
            Continue with Google
          </button>
          <button type="button" className="btn login-btn login-facebook" onClick={() => onSocial('facebook')}>
            <span className="login-btn-icon">f</span>
            Continue with Facebook
          </button>
          <button type="button" className="btn login-btn login-microsoft" onClick={() => onSocial('microsoft')}>
            <span className="login-btn-icon">⊞</span>
            Continue with Microsoft
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
