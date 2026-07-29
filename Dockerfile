# Build client + run Express (serves API + client/dist)
FROM node:20-bookworm-slim AS client-build
WORKDIR /app/client
COPY client/package.json client/package-lock.json* ./
RUN npm ci --include=dev || npm install --include=dev
COPY client/ ./
# Same-origin /api on the VM — leave empty
ENV VITE_API_URL=
RUN npm run build

FROM node:20-bookworm-slim AS server
WORKDIR /app
COPY server/package.json server/package-lock.json* ./server/
RUN cd server && (npm ci --omit=dev || npm install --omit=dev)
COPY server/ ./server/
COPY --from=client-build /app/client/dist ./client/dist

ENV NODE_ENV=production
ENV PORT=5000
WORKDIR /app/server
EXPOSE 5000
# Schema on start (safe IF NOT EXISTS) then API
CMD ["sh", "-c", "node src/initDb.js && node src/index.js"]
