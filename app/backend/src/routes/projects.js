const express = require('express');
const { body, validationResult } = require('express-validator');
const db = require('../config/database');
const { authenticate } = require('../middleware/auth');

const router = express.Router();
router.use(authenticate);

// ── GET /api/projects ────────────────────────────────────
router.get('/', async (req, res, next) => {
  try {
    const { rows } = await db.query(
      `SELECT
         p.*,
         u.name AS owner_name,
         COUNT(DISTINCT t.id)::int AS task_count,
         COUNT(DISTINCT t.id) FILTER (WHERE t.status = 'done')::int AS done_count,
         COUNT(DISTINCT pm.user_id)::int AS member_count
       FROM projects p
       LEFT JOIN users u ON u.id = p.owner_id
       LEFT JOIN tasks t ON t.project_id = p.id
       LEFT JOIN project_members pm ON pm.project_id = p.id
       WHERE p.owner_id = $1
          OR p.id IN (SELECT project_id FROM project_members WHERE user_id = $1)
       GROUP BY p.id, u.name
       ORDER BY p.updated_at DESC`,
      [req.user.id]
    );
    res.json(rows);
  } catch (err) {
    next(err);
  }
});

// ── GET /api/projects/:id ────────────────────────────────
router.get('/:id', async (req, res, next) => {
  try {
    const { rows } = await db.query(
      `SELECT p.*, u.name AS owner_name
       FROM projects p
       LEFT JOIN users u ON u.id = p.owner_id
       WHERE p.id = $1`,
      [req.params.id]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Project not found' });

    // Fetch members
    const { rows: members } = await db.query(
      `SELECT u.id, u.name, u.email, pm.role, pm.joined_at
       FROM project_members pm
       JOIN users u ON u.id = pm.user_id
       WHERE pm.project_id = $1`,
      [req.params.id]
    );

    res.json({ ...rows[0], members });
  } catch (err) {
    next(err);
  }
});

// ── POST /api/projects ───────────────────────────────────
router.post(
  '/',
  [
    body('name').trim().isLength({ min: 2, max: 200 }).withMessage('Name must be 2–200 chars'),
    body('description').optional().trim().isLength({ max: 2000 }),
  ],
  async (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Validation failed', details: errors.array() });
    }

    const { name, description } = req.body;
    const client = await db.pool.connect();
    try {
      await client.query('BEGIN');

      const { rows } = await client.query(
        `INSERT INTO projects (name, description, owner_id)
         VALUES ($1, $2, $3)
         RETURNING *`,
        [name, description || null, req.user.id]
      );
      const project = rows[0];

      // Auto-add creator as owner member
      await client.query(
        `INSERT INTO project_members (project_id, user_id, role)
         VALUES ($1, $2, 'owner')`,
        [project.id, req.user.id]
      );

      await client.query('COMMIT');
      res.status(201).json(project);
    } catch (err) {
      await client.query('ROLLBACK');
      next(err);
    } finally {
      client.release();
    }
  }
);

// ── PATCH /api/projects/:id ──────────────────────────────
router.patch(
  '/:id',
  [
    body('name').optional().trim().isLength({ min: 2, max: 200 }),
    body('status').optional().isIn(['active', 'archived', 'completed']),
    body('description').optional().trim().isLength({ max: 2000 }),
  ],
  async (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Validation failed', details: errors.array() });
    }

    const { name, description, status } = req.body;
    try {
      const { rows } = await db.query(
        `UPDATE projects
         SET name        = COALESCE($1, name),
             description = COALESCE($2, description),
             status      = COALESCE($3, status)
         WHERE id = $4 AND owner_id = $5
         RETURNING *`,
        [name, description, status, req.params.id, req.user.id]
      );
      if (!rows[0]) return res.status(404).json({ error: 'Project not found or access denied' });
      res.json(rows[0]);
    } catch (err) {
      next(err);
    }
  }
);

// ── DELETE /api/projects/:id ─────────────────────────────
router.delete('/:id', async (req, res, next) => {
  try {
    const { rowCount } = await db.query(
      'DELETE FROM projects WHERE id = $1 AND owner_id = $2',
      [req.params.id, req.user.id]
    );
    if (!rowCount) return res.status(404).json({ error: 'Project not found or access denied' });
    res.status(204).end();
  } catch (err) {
    next(err);
  }
});

// ── GET /api/projects/:id/stats ──────────────────────────
router.get('/:id/stats', async (req, res, next) => {
  try {
    const { rows } = await db.query(
      `SELECT
         COUNT(*)::int AS total,
         COUNT(*) FILTER (WHERE status = 'todo')::int AS todo,
         COUNT(*) FILTER (WHERE status = 'in_progress')::int AS in_progress,
         COUNT(*) FILTER (WHERE status = 'review')::int AS review,
         COUNT(*) FILTER (WHERE status = 'done')::int AS done,
         COUNT(*) FILTER (WHERE priority = 'critical')::int AS critical,
         COUNT(*) FILTER (WHERE due_date < NOW() AND status != 'done')::int AS overdue
       FROM tasks WHERE project_id = $1`,
      [req.params.id]
    );
    res.json(rows[0]);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
