/**
 * Vercel serverless entry for /api/*
 * Dependencies are hoisted at repo root (package.json) so the function can resolve them.
 */
import app from '../server/src/app.js';

export default app;
