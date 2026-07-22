import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import App from './App';
import { ThemeProvider } from './theme/ThemeContext';
/* Design tokens from /design folder */
import '../../design/variables.css';
import './index.css';

// Apply saved theme before paint when possible (default: dark for the app)
try {
  const t = localStorage.getItem('sanchiva.theme');
  const theme = t === 'light' || t === 'dark' ? t : 'dark';
  document.documentElement.setAttribute('data-theme', theme);
  document.documentElement.classList.add(theme === 'dark' ? 'theme-dark' : 'theme-light');
} catch {
  document.documentElement.setAttribute('data-theme', 'dark');
  document.documentElement.classList.add('theme-dark');
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
