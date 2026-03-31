const express = require('express');
const db = require('../config/database');

const healthRouter = express.Router();
const metricsRouter = express.Router();

// ── GET /health ──────────────────────────────────────────
// Kubernetes Liveness probe
healthRouter.get('/', async (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// ── GET /health/ready ────────────────────────────────────
// Kubernetes Readiness probe (checks DB)
healthRouter.get('/ready', async (req, res) => {
  try {
    await db.query('SELECT 1');
    res.json({ status: 'ready', db: 'connected', timestamp: new Date().toISOString() });
  } catch (err) {
    res.status(503).json({ status: 'not ready', db: 'disconnected', error: err.message });
  }
});

// ── GET /health/live ─────────────────────────────────────
healthRouter.get('/live', (req, res) => {
  res.json({ status: 'alive', uptime: process.uptime(), timestamp: new Date().toISOString() });
});

// ── GET /metrics ─────────────────────────────────────────
// Prometheus scrape endpoint
metricsRouter.get('/', async (req, res) => {
  try {
    const register = req.app.locals.metricsRegistry;
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  } catch (err) {
    res.status(500).end(err.message);
  }
});

module.exports = healthRouter;
module.exports.metricsRouter = metricsRouter;
