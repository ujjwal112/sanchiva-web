import app from './app.js';

const PORT = process.env.PORT || 5000;

// Vercel imports the app as a serverless function — do not call listen there.
if (!process.env.VERCEL) {
  app.listen(PORT, () => {
    console.log(`Sanchiva API running on port ${PORT}`);
    console.log(`Swagger UI: http://localhost:${PORT}/api/docs`);
  });
}

export default app;
