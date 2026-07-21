import { useState } from 'react';
import { Link, Navigate, useNavigate } from 'react-router-dom';
import Logo from '../components/Logo';
import { useAuth } from '../auth/AuthContext';

export default function Signup() {
  const { isAuthenticated, loading, registerWithPassword } = useAuth();
  const navigate = useNavigate();
  const [message, setMessage] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [form, setForm] = useState({
    name: '',
    email: '',
    password: '',
    confirm_password: '',
  });

  if (!loading && isAuthenticated) return <Navigate to="/dashboard" replace />;

  const set = (key) => (e) => setForm((f) => ({ ...f, [key]: e.target.value }));

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
        <p className="muted login-sub">
          Sign up with your name, email, and password. Prefer Google? Use{' '}
          <Link to="/login">Login</Link> with Google (that creates your account too).
        </p>

        {message && <div className="login-error">{message}</div>}

        <form className="auth-form" onSubmit={onSubmit}>
          <div className="field">
            <input
              id="signup-name"
              autoComplete="name"
              required
              autoFocus
              aria-label="Name"
              value={form.name}
              onChange={set('name')}
              placeholder="Name"
            />
          </div>
          <div className="field">
            <input
              id="signup-email"
              type="email"
              autoComplete="email"
              required
              aria-label="Email"
              value={form.email}
              onChange={set('email')}
              placeholder="Email"
            />
          </div>
          <div className="field">
            <input
              id="signup-password"
              type="password"
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
            <input
              id="signup-confirm"
              type="password"
              autoComplete="new-password"
              required
              minLength={8}
              aria-label="Confirm password"
              value={form.confirm_password}
              onChange={set('confirm_password')}
              placeholder="Confirm password"
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
