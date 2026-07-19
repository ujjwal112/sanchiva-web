import { useEffect, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';

export default function AuthCallback() {
  const [params] = useSearchParams();
  const { completeLogin } = useAuth();
  const navigate = useNavigate();
  const [error, setError] = useState('');

  useEffect(() => {
    const access = params.get('access_token');
    const refresh = params.get('refresh_token');
    if (!access || !refresh) {
      setError('Missing tokens from login provider');
      return;
    }
    completeLogin(access, refresh)
      .then(() => navigate('/', { replace: true }))
      .catch((e) => setError(e.message || 'Login failed'));
  }, [params, completeLogin, navigate]);

  if (error) {
    return (
      <div className="login-page">
        <div className="login-card card">
          <h3>Login error</h3>
          <p className="muted">{error}</p>
          <a className="btn btn-primary" href="/login">
            Back to login
          </a>
        </div>
      </div>
    );
  }

  return (
    <div className="login-page">
      <div className="login-card card">
        <p className="muted">Signing you in…</p>
      </div>
    </div>
  );
}
