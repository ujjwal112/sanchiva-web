import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import passport from 'passport';
import swaggerUi from 'swagger-ui-express';
import pool from './db.js';

import authRouter, { configurePassport } from './auth/oauth.js';
import categoriesRouter from './routes/categories.js';
import expensesRouter from './routes/expenses.js';
import loansRouter from './routes/loans.js';
import creditCardsRouter from './routes/creditCards.js';
import monetaryRouter from './routes/monetary.js';
import eventsRouter from './routes/events.js';
import dashboardRouter from './routes/dashboard.js';
import fxRouter from './routes/fx.js';
import metalsRouter from './routes/metals.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, '..', '.env') });

const openapi = JSON.parse(fs.readFileSync(path.join(__dirname, 'openapi.json'), 'utf8'));

const app = express();

const allowedOrigins = (process.env.CLIENT_ORIGIN || 'http://localhost:5173')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);

app.use(
  cors({
    origin(origin, callback) {
      if (!origin) return callback(null, true);
      if (allowedOrigins.includes('*') || allowedOrigins.includes(origin)) {
        return callback(null, true);
      }
      // Allow same-origin / preview URLs (Vercel)
      return callback(null, true);
    },
    credentials: true,
  })
);
app.use(express.json());
app.use(passport.initialize());
configurePassport();

app.get('/api/openapi.json', (_req, res) => {
  res.json(openapi);
});
app.use(
  '/api/docs',
  swaggerUi.serve,
  swaggerUi.setup(openapi, {
    customSiteTitle: 'Sanchiva API Docs',
    swaggerOptions: {
      persistAuthorization: true,
      displayRequestDuration: true,
      tryItOutEnabled: true,
      initOAuth: false,
    },
  })
);

app.get('/api/health', async (_req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({
      ok: true,
      db: true,
      env: process.env.NODE_ENV || 'development',
      platform: process.env.VERCEL ? 'vercel' : 'node',
    });
  } catch (err) {
    res.status(500).json({ ok: false, db: false, error: err.message });
  }
});

app.use('/api/auth', authRouter);
app.use('/api/categories', categoriesRouter);
app.use('/api/expenses', expensesRouter);
app.use('/api/loans', loansRouter);
app.use('/api/credit-cards', creditCardsRouter);
app.use('/api/monetary', monetaryRouter);
app.use('/api/events', eventsRouter);
app.use('/api/dashboard', dashboardRouter);
app.use('/api/fx', fxRouter);
app.use('/api/metals', metalsRouter);

// Static SPA only for long-running Node hosts (Render / local). Vercel serves client/dist itself.
const clientDist = path.join(__dirname, '..', '..', 'client', 'dist');
if (!process.env.VERCEL && fs.existsSync(clientDist)) {
  app.use(express.static(clientDist));
  app.get('*', (req, res, next) => {
    if (req.path.startsWith('/api')) return next();
    res.sendFile(path.join(clientDist, 'index.html'));
  });
}

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: err.message || 'Server error' });
});

export default app;
