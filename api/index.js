/**
 * Vercel serverless entry — mounts the Express app for all /api/* routes.
 * Local/Render continue to use: node server/src/index.js
 */
import app from '../server/src/app.js';

export default app;
