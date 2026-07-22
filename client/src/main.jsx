import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import App from './App';
import { ThemeProvider } from './theme/ThemeContext';
/* Design tokens from /design folder */
import '../../design/variables.css';
import './index.css';

// Apply saved theme before paint when possible
try {
  const t = localStorage.getItem('sanchiva.theme');
  if (t === 'dark' || t === 'light') {
    document.documentElement.setAttribute('data-theme', t);
    document.documentElement.classList.add(t === 'dark' ? 'theme-dark' : 'theme-light');
  }
} catch {
  /* ignore */
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
