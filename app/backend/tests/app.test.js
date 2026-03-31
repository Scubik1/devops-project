const request = require('supertest');
const app = require('../src/index');

// Mock database to avoid real DB calls in unit tests
jest.mock('../src/config/database', () => ({
  query: jest.fn(),
  connect: jest.fn(),
  end: jest.fn(),
  pool: { connect: jest.fn() },
}));

jest.mock('../src/db/migrations', () => ({
  runMigrations: jest.fn().mockResolvedValue(undefined),
}));

const db = require('../src/config/database');

describe('Health Endpoints', () => {
  test('GET /health returns 200', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('status', 'ok');
    expect(res.body).toHaveProperty('timestamp');
  });

  test('GET /health/live returns 200', async () => {
    const res = await request(app).get('/health/live');
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('status', 'alive');
    expect(res.body).toHaveProperty('uptime');
  });

  test('GET /health/ready returns 200 when DB is up', async () => {
    db.query.mockResolvedValueOnce({ rows: [] });
    const res = await request(app).get('/health/ready');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ready');
  });

  test('GET /health/ready returns 503 when DB is down', async () => {
    db.query.mockRejectedValueOnce(new Error('connection refused'));
    const res = await request(app).get('/health/ready');
    expect(res.status).toBe(503);
    expect(res.body.status).toBe('not ready');
  });
});

describe('Auth Endpoints', () => {
  test('POST /api/auth/register — validation error on empty body', async () => {
    const res = await request(app).post('/api/auth/register').send({});
    expect(res.status).toBe(400);
    expect(res.body).toHaveProperty('error');
  });

  test('POST /api/auth/login — validation error on empty body', async () => {
    const res = await request(app).post('/api/auth/login').send({});
    expect(res.status).toBe(400);
    expect(res.body).toHaveProperty('error');
  });

  test('GET /api/auth/me — returns 401 without token', async () => {
    const res = await request(app).get('/api/auth/me');
    expect(res.status).toBe(401);
  });
});

describe('Projects Endpoints', () => {
  test('GET /api/projects — returns 401 without token', async () => {
    const res = await request(app).get('/api/projects');
    expect(res.status).toBe(401);
  });
});

describe('Tasks Endpoints', () => {
  test('GET /api/tasks — returns 401 without token', async () => {
    const res = await request(app).get('/api/tasks');
    expect(res.status).toBe(401);
  });
});

describe('404 handler', () => {
  test('unknown route returns 404', async () => {
    const res = await request(app).get('/api/unknown');
    expect(res.status).toBe(404);
  });
});
