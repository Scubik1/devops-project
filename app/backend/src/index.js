const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const { collectDefaultMetrics, Registry } = require('prom-client');

const logger = require('./config/logger');
const db = require('./config/database');
const { runMigrations } = require('./db/migrations');
const errorHandler = require('./middleware/errorHandler');

const authRoutes = require('./routes/auth');
const projectRoutes = require('./routes/projects');
const taskRoutes = require('./routes/tasks');
const healthRoutes = require('./routes/health');
const metricsRoutes = require('./routes/metrics');

const app = express();
const PORT = process.env.PORT || 4000;

// ── Prometheus metrics ──────────────────────────────────
const register = new Registry();
collectDefaultMetrics({ register });
app.locals.metricsRegistry = register;

// ── Security & parsing middleware ───────────────────────
app.use(helmet());
app.use(cors({
  origin: process.env.FRONTEND_URL || 'http://localhost:3000',
  credentials: true,
}));
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true }));

// ── Request logging middleware ──────────────────────────
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    logger.info(`${req.method} ${req.path} ${res.statusCode} ${Date.now() - start}ms`);
  });
  next();
});

// ── Routes ──────────────────────────────────────────────
app.use('/health', healthRoutes);
app.use('/metrics', metricsRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/projects', projectRoutes);
app.use('/api/tasks', taskRoutes);

// ── 404 handler ─────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// ── Global error handler ─────────────────────────────────
app.use(errorHandler);

// ── Start server ─────────────────────────────────────────
async function start() {
  try {
    await db.connect();
    logger.info('Database connection established');

    await runMigrations();
    logger.info('Database migrations completed');

    app.listen(PORT, () => {
      logger.info(`DevTracker API running on port ${PORT}`);
    });
  } catch (err) {
    logger.error('Failed to start server:', err);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGTERM', async () => {
  logger.info('SIGTERM received, shutting down gracefully...');
  await db.end();
  process.exit(0);
});

process.on('SIGINT', async () => {
  await db.end();
  process.exit(0);
});

start();

module.exports = app;
