const express = require('express');
const bcrypt = require('bcryptjs');
const { body, validationResult } = require('express-validator');
const db = require('../config/database');
const { generateToken, authenticate } = require('../middleware/auth');

const router = express.Router();

// ── POST /api/auth/register ──────────────────────────────
router.post(
  '/register',
  [
    body('name').trim().isLength({ min: 2, max: 100 }).withMessage('Name must be 2–100 chars'),
    body('email').isEmail().normalizeEmail().withMessage('Valid email required'),
    body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 chars'),
  ],
  async (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Validation failed', details: errors.array() });
    }

    const { name, email, password } = req.body;
    try {
      const hash = await bcrypt.hash(password, 12);
      const { rows } = await db.query(
        'INSERT INTO users (name, email, password) VALUES ($1, $2, $3) RETURNING id, name, email, role, created_at',
        [name, email, hash]
      );
      const user = rows[0];
      const token = generateToken(user);
      res.status(201).json({ token, user });
    } catch (err) {
      next(err);
    }
  }
);

// ── POST /api/auth/login ─────────────────────────────────
router.post(
  '/login',
  [
    body('email').isEmail().normalizeEmail(),
    body('password').notEmpty(),
  ],
  async (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Validation failed', details: errors.array() });
    }

    const { email, password } = req.body;
    try {
      const { rows } = await db.query(
        'SELECT * FROM users WHERE email = $1',
        [email]
      );
      const user = rows[0];
      if (!user) {
        return res.status(401).json({ error: 'Invalid email or password' });
      }

      const valid = await bcrypt.compare(password, user.password);
      if (!valid) {
        return res.status(401).json({ error: 'Invalid email or password' });
      }

      const { password: _, ...safeUser } = user;
      const token = generateToken(safeUser);
      res.json({ token, user: safeUser });
    } catch (err) {
      next(err);
    }
  }
);

// ── GET /api/auth/me ─────────────────────────────────────
router.get('/me', authenticate, async (req, res, next) => {
  try {
    const { rows } = await db.query(
      'SELECT id, name, email, role, created_at FROM users WHERE id = $1',
      [req.user.id]
    );
    if (!rows[0]) return res.status(404).json({ error: 'User not found' });
    res.json(rows[0]);
  } catch (err) {
    next(err);
  }
});

// ── GET /api/auth/users ──────────────────────────────────
// Returns list of users (for task assignment)
router.get('/users', authenticate, async (req, res, next) => {
  try {
    const { rows } = await db.query(
      'SELECT id, name, email, role FROM users ORDER BY name'
    );
    res.json(rows);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
