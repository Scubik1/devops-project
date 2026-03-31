const express = require('express');
const { body, query, validationResult } = require('express-validator');
const db = require('../config/database');
const { authenticate } = require('../middleware/auth');

const router = express.Router();
router.use(authenticate);

// ── GET /api/tasks?project_id=&status=&priority=&assignee_id= ──
router.get('/', async (req, res, next) => {
  const { project_id, status, priority, assignee_id } = req.query;

  const conditions = [];
  const params = [];

  if (project_id) {
    params.push(project_id);
    conditions.push(`t.project_id = $${params.length}`);
  }
  if (status) {
    params.push(status);
    conditions.push(`t.status = $${params.length}`);
  }
  if (priority) {
    params.push(priority);
    conditions.push(`t.priority = $${params.length}`);
  }
  if (assignee_id) {
    params.push(assignee_id);
    conditions.push(`t.assignee_id = $${params.length}`);
  }

  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

  try {
    const { rows } = await db.query(
      `SELECT
         t.*,
         u.name  AS assignee_name,
         u.email AS assignee_email,
         c.name  AS created_by_name,
         p.name  AS project_name
       FROM tasks t
       LEFT JOIN users u ON u.id = t.assignee_id
       LEFT JOIN users c ON c.id = t.created_by
       LEFT JOIN projects p ON p.id = t.project_id
       ${where}
       ORDER BY
         CASE t.priority
           WHEN 'critical' THEN 1
           WHEN 'high'     THEN 2
           WHEN 'medium'   THEN 3
           WHEN 'low'      THEN 4
         END,
         t.created_at DESC`,
      params
    );
    res.json(rows);
  } catch (err) {
    next(err);
  }
});

// ── GET /api/tasks/:id ───────────────────────────────────
router.get('/:id', async (req, res, next) => {
  try {
    const { rows } = await db.query(
      `SELECT
         t.*,
         u.name  AS assignee_name,
         u.email AS assignee_email,
         c.name  AS created_by_name,
         p.name  AS project_name
       FROM tasks t
       LEFT JOIN users u ON u.id = t.assignee_id
       LEFT JOIN users c ON c.id = t.created_by
       LEFT JOIN projects p ON p.id = t.project_id
       WHERE t.id = $1`,
      [req.params.id]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Task not found' });
    res.json(rows[0]);
  } catch (err) {
    next(err);
  }
});

// ── POST /api/tasks ──────────────────────────────────────
router.post(
  '/',
  [
    body('title').trim().isLength({ min: 2, max: 300 }).withMessage('Title must be 2–300 chars'),
    body('description').optional().trim().isLength({ max: 5000 }),
    body('project_id').isInt({ min: 1 }).withMessage('Valid project_id required'),
    body('status').optional().isIn(['todo', 'in_progress', 'review', 'done']),
    body('priority').optional().isIn(['low', 'medium', 'high', 'critical']),
    body('assignee_id').optional().isInt({ min: 1 }),
    body('due_date').optional().isISO8601().toDate(),
  ],
  async (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Validation failed', details: errors.array() });
    }

    const { title, description, project_id, status, priority, assignee_id, due_date } = req.body;
    try {
      const { rows } = await db.query(
        `INSERT INTO tasks
           (title, description, project_id, status, priority, assignee_id, created_by, due_date)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         RETURNING *`,
        [
          title,
          description || null,
          project_id,
          status || 'todo',
          priority || 'medium',
          assignee_id || null,
          req.user.id,
          due_date || null,
        ]
      );
      res.status(201).json(rows[0]);
    } catch (err) {
      next(err);
    }
  }
);

// ── PATCH /api/tasks/:id ─────────────────────────────────
router.patch(
  '/:id',
  [
    body('title').optional().trim().isLength({ min: 2, max: 300 }),
    body('description').optional().trim().isLength({ max: 5000 }),
    body('status').optional().isIn(['todo', 'in_progress', 'review', 'done']),
    body('priority').optional().isIn(['low', 'medium', 'high', 'critical']),
    body('assignee_id').optional().isInt({ min: 1 }).nullable(),
    body('due_date').optional().isISO8601().toDate().nullable(),
  ],
  async (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ error: 'Validation failed', details: errors.array() });
    }

    const { title, description, status, priority, assignee_id, due_date } = req.body;
    try {
      const { rows } = await db.query(
        `UPDATE tasks
         SET title       = COALESCE($1, title),
             description = COALESCE($2, description),
             status      = COALESCE($3, status),
             priority    = COALESCE($4, priority),
             assignee_id = COALESCE($5, assignee_id),
             due_date    = COALESCE($6, due_date)
         WHERE id = $7
         RETURNING *`,
        [title, description, status, priority, assignee_id, due_date, req.params.id]
      );
      if (!rows[0]) return res.status(404).json({ error: 'Task not found' });
      res.json(rows[0]);
    } catch (err) {
      next(err);
    }
  }
);

// ── DELETE /api/tasks/:id ────────────────────────────────
router.delete('/:id', async (req, res, next) => {
  try {
    const { rowCount } = await db.query(
      'DELETE FROM tasks WHERE id = $1',
      [req.params.id]
    );
    if (!rowCount) return res.status(404).json({ error: 'Task not found' });
    res.status(204).end();
  } catch (err) {
    next(err);
  }
});

module.exports = router;
