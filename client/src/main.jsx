import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import App from './App';
import { ThemeProvider } from './theme/ThemeContext';
/* Design tokens (kept inside client so deploys don't need /design) */
import './design-tokens.css';
import './index.css';

// Apply saved theme before paint when possible (default: light for the app)
try {
  const t = localStorage.getItem('sanchiva.theme');
  const theme = t === 'light' || t === 'dark' ? t : 'light';
  document.documentElement.setAttribute('data-theme', theme);
  document.documentElement.classList.add(theme === 'dark' ? 'theme-dark' : 'theme-light');
} catch {
  document.documentElement.setAttribute('data-theme', 'light');
  document.documentElement.classList.add('theme-light');
}

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <BrowserRouter>
      <ThemeProvider>
        <App />
      </ThemeProvider>
    </BrowserRouter>
  </React.StrictMode>
);
