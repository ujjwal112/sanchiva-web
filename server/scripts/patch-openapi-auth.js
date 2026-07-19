import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const openapiPath = path.join(__dirname, '..', 'src', 'openapi.json');
const o = JSON.parse(fs.readFileSync(openapiPath, 'utf8'));

o.info.description = [
  'Sanchiva — Everything that matters, one place. REST API for expenses, loans, monetary data, and events.',
  '',
  '## Authentication',
  'Most endpoints require a JWT **Bearer** access token.',
  '',
  '1. Call **POST /api/auth/guest** (or sign in via Google OAuth in the app) to get `access_token`.',
  '2. Click **Authorize** (lock icon, top right).',
  '3. Paste the access token only (Swagger adds the word Bearer for you).',
  '4. Click **Authorize** → **Close**, then try protected endpoints.',
  '',
  '**Developed by Ujjwal Gupta**',
].join('\n');

if (!o.tags.some((t) => t.name === 'Auth')) {
  o.tags.unshift({ name: 'Auth', description: 'Login, tokens, current user' });
}

o.security = [{ bearerAuth: [] }];

o.components = o.components || {};
o.components.securitySchemes = {
  bearerAuth: {
    type: 'http',
    scheme: 'bearer',
    bearerFormat: 'JWT',
    description:
      'Paste your JWT access token (from POST /api/auth/guest or login). Do not include the word "Bearer".',
  },
};

if (o.paths['/api/health']?.get) {
  o.paths['/api/health'].get.security = [];
}

const authPaths = {
  '/api/auth/guest': {
    post: {
      tags: ['Auth'],
      summary: 'Create a guest session',
      description: 'Returns access_token and refresh_token. Use access_token in Authorize.',
      security: [],
      responses: {
        200: {
          description: 'Tokens issued',
          content: {
            'application/json': {
              example: {
                user: { id: 1, name: 'Guest User', provider: 'guest' },
                access_token: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
                refresh_token: 'raw-refresh-token',
                token_type: 'Bearer',
              },
            },
          },
        },
      },
    },
  },
  '/api/auth/refresh': {
    post: {
      tags: ['Auth'],
      summary: 'Refresh access token',
      security: [],
      requestBody: {
        required: true,
        content: {
          'application/json': {
            schema: {
              type: 'object',
              required: ['refresh_token'],
              properties: { refresh_token: { type: 'string' } },
            },
            example: { refresh_token: 'your-refresh-token' },
          },
        },
      },
      responses: { 200: { description: 'New access and refresh tokens' } },
    },
  },
  '/api/auth/me': {
    get: {
      tags: ['Auth'],
      summary: 'Current authenticated user',
      security: [{ bearerAuth: [] }],
      responses: {
        200: { description: 'User profile' },
        401: { description: 'Unauthorized' },
      },
    },
  },
  '/api/auth/logout': {
    post: {
      tags: ['Auth'],
      summary: 'Logout (revokes refresh token; wipes guest data)',
      security: [{ bearerAuth: [] }],
      requestBody: {
        content: {
          'application/json': {
            schema: {
              type: 'object',
              properties: { refresh_token: { type: 'string' } },
            },
          },
        },
      },
      responses: { 200: { description: 'Logged out' } },
    },
  },
  '/api/auth/providers': {
    get: {
      tags: ['Auth'],
      summary: 'Which OAuth providers are configured',
      security: [],
      responses: { 200: { description: 'Provider flags' } },
    },
  },
};

// Avoid duplicating if script re-run
for (const p of Object.keys(authPaths)) {
  o.paths[p] = authPaths[p];
}

// Keep health first-ish: rebuild paths with auth + health then rest
const ordered = {};
for (const p of ['/api/health', ...Object.keys(authPaths)]) {
  if (o.paths[p]) ordered[p] = o.paths[p];
}
for (const [p, v] of Object.entries(o.paths)) {
  if (!ordered[p]) ordered[p] = v;
}
o.paths = ordered;

fs.writeFileSync(openapiPath, JSON.stringify(o, null, 2) + '\n');
console.log('Patched', openapiPath);
console.log('securitySchemes:', Object.keys(o.components.securitySchemes));
console.log('global security:', JSON.stringify(o.security));
