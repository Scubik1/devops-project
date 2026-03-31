const { Pool } = require('pg');
const logger = require('./logger');

const pool = new Pool({
  host:     process.env.DB_HOST     || 'localhost',
  port:     parseInt(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME     || 'devtracker',
  user:     process.env.DB_USER     || 'devtracker',
  password: process.env.DB_PASSWORD || 'devtracker',
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

pool.on('error', (err) => {
  logger.error('Unexpected DB pool error:', err);
});

module.exports = {
  connect: () => pool.connect(),
  query:   (text, params) => pool.query(text, params),
  end:     () => pool.end(),
  pool,
};
