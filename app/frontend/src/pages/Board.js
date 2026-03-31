import React, { useState, useEffect, useCallback } from 'react';
import { useAuth } from '../App';
import api from '../api/axios';
import Modal from '../components/Modal';
import { StatusBadge, PriorityBadge } from '../components/Badge';

const COLUMNS = [
  { key: 'todo',        label: 'К выполнению', color: 'var(--gray-400)' },
  { key: 'in_progress', label: 'В работе',     color: '#2563EB'         },
  { key: 'review',      label: 'Ревью',         color: 'var(--orange)'  },
  { key: 'done',        label: 'Готово',        color: 'var(--green)'   },
];

const PRIORITIES = ['low', 'medium', 'high', 'critical'];
const PRIORITY_LABELS = { low: 'Низкий', medium: 'Средний', high: 'Высокий', critical: 'Критический' };
const STATUS_LABELS = { todo: 'К выполнению', in_progress: 'В работе', review: 'Ревью', done: 'Готово' };

function formatDate(dateStr) {
  if (!dateStr) return null;
  const d = new Date(dateStr);
  return d.toLocaleDateString('ru-RU', { day: '2-digit', month: '2-digit' });
}

function isOverdue(dateStr, status) {
  if (!dateStr || status === 'done') return false;
  return new Date(dateStr) < new Date();
}

// ── Task Card ──────────────────────────────────────────
function TaskCard({ task, onClick }) {
  const initials = task.assignee_name
    ? task.assignee_name.split(' ').map(w => w[0]).join('').slice(0, 2).toUpperCase()
    : null;
  const overdue = isOverdue(task.due_date, task.status);

  return (
    <div className="task-card" onClick={() => onClick(task)}>
      <div className="task-card-title">{task.title}</div>
      <div className="task-card-meta">
        <PriorityBadge priority={task.priority} />
        {task.due_date && (
          <span className={`due-date ${overdue ? 'overdue' : ''}`}>
            {overdue ? '⚠ ' : '📅 '}{formatDate(task.due_date)}
          </span>
        )}
      </div>
      {(task.assignee_name || task.description) && (
        <div className="task-card-bottom">
          {task.assignee_name ? (
            <div className="task-assignee">
              <div className="avatar-sm">{initials}</div>
              <span>{task.assignee_name}</span>
            </div>
          ) : <span />}
          {task.description && (
            <span style={{ fontSize: 11, color: 'var(--gray-400)' }}>📝</span>
          )}
        </div>
      )}
    </div>
  );
}

// ── Task Form Modal ────────────────────────────────────
function TaskModal({ task, projectId, users, onClose, onSaved }) {
  const { user } = useAuth();
  const isEdit = !!task;

  const [form, setForm] = useState({
    title:       task?.title       || '',
    description: task?.description || '',
    status:      task?.status      || 'todo',
    priority:    task?.priority    || 'medium',
    assignee_id: task?.assignee_id || '',
    due_date:    task?.due_date ? task.due_date.slice(0, 10) : '',
  });
  const [saving, setSaving] = useState(false);
  const [error, setError]   = useState('');
  const [deleting, setDeleting] = useState(false);

  const setField = (k, v) => setForm(f => ({ ...f, [k]: v }));

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setSaving(true);
    const payload = {
      ...form,
      project_id:  projectId,
      assignee_id: form.assignee_id ? parseInt(form.assignee_id) : null,
      due_date:    form.due_date || null,
    };
    try {
      if (isEdit) {
        await api.patch(`/tasks/${task.id}`, payload);
      } else {
        await api.post('/tasks', payload);
      }
      onSaved();
      onClose();
    } catch (err) {
      setError(err.response?.data?.error || 'Ошибка сохранения');
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async () => {
    if (!window.confirm('Удалить задачу?')) return;
    setDeleting(true);
    try {
      await api.delete(`/tasks/${task.id}`);
      onSaved();
      onClose();
    } catch (err) {
      setError(err.response?.data?.error || 'Ошибка удаления');
    } finally {
      setDeleting(false);
    }
  };

  return (
    <Modal
      title={isEdit ? 'Редактировать задачу' : 'Новая задача'}
      onClose={onClose}
      footer={
        <div style={{ display: 'flex', justifyContent: 'space-between', width: '100%' }}>
          <div>
            {isEdit && (
              <button className="btn btn-danger btn-sm" onClick={handleDelete} disabled={deleting}>
                {deleting ? '...' : 'Удалить'}
              </button>
            )}
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <button className="btn btn-ghost" onClick={onClose}>Отмена</button>
            <button className="btn btn-primary" form="task-form" type="submit" disabled={saving}>
              {saving ? 'Сохранение...' : isEdit ? 'Сохранить' : 'Создать'}
            </button>
          </div>
        </div>
      }
    >
      {error && <div className="alert alert-error">{error}</div>}

      <form id="task-form" onSubmit={handleSubmit} style={{ display: 'contents' }}>
        {/* Title */}
        <div className="form-group">
          <label className="form-label">Название *</label>
          <input
            className="form-control"
            value={form.title}
            onChange={e => setField('title', e.target.value)}
            placeholder="Что нужно сделать?"
            required
            autoFocus
          />
        </div>

        {/* Description */}
        <div className="form-group">
          <label className="form-label">Описание</label>
          <textarea
            className="form-control"
            value={form.description}
            onChange={e => setField('description', e.target.value)}
            placeholder="Подробности задачи..."
            rows={3}
          />
        </div>

        {/* Status + Priority */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
          <div className="form-group">
            <label className="form-label">Статус</label>
            <select className="form-control" value={form.status} onChange={e => setField('status', e.target.value)}>
              {Object.entries(STATUS_LABELS).map(([v, l]) => (
                <option key={v} value={v}>{l}</option>
              ))}
            </select>
          </div>

          <div className="form-group">
            <label className="form-label">Приоритет</label>
            <select className="form-control" value={form.priority} onChange={e => setField('priority', e.target.value)}>
              {PRIORITIES.map(p => (
                <option key={p} value={p}>{PRIORITY_LABELS[p]}</option>
              ))}
            </select>
          </div>
        </div>

        {/* Assignee + Due date */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
          <div className="form-group">
            <label className="form-label">Исполнитель</label>
            <select className="form-control" value={form.assignee_id} onChange={e => setField('assignee_id', e.target.value)}>
              <option value="">Не назначен</option>
              {users.map(u => (
                <option key={u.id} value={u.id}>{u.name}</option>
              ))}
            </select>
          </div>

          <div className="form-group">
            <label className="form-label">Срок</label>
            <input
              className="form-control"
              type="date"
              value={form.due_date}
              onChange={e => setField('due_date', e.target.value)}
            />
          </div>
        </div>
      </form>
    </Modal>
  );
}

// ── Main Board ─────────────────────────────────────────
export default function Board({ projectId, navigate }) {
  const [project, setProject] = useState(null);
  const [tasks, setTasks]     = useState([]);
  const [users, setUsers]     = useState([]);
  const [stats, setStats]     = useState(null);
  const [loading, setLoading] = useState(true);
  const [modalTask, setModalTask]   = useState(undefined); // undefined = closed, null = new, task = edit
  const [search, setSearch]         = useState('');
  const [filterPriority, setFilterPriority] = useState('all');
  const [filterAssignee, setFilterAssignee] = useState('all');

  const fetchAll = useCallback(() => {
    Promise.all([
      api.get(`/projects/${projectId}`),
      api.get(`/tasks?project_id=${projectId}`),
      api.get('/auth/users'),
      api.get(`/projects/${projectId}/stats`),
    ]).then(([pRes, tRes, uRes, sRes]) => {
      setProject(pRes.data);
      setTasks(tRes.data);
      setUsers(uRes.data);
      setStats(sRes.data);
    }).catch(() => navigate('/projects'))
    .finally(() => setLoading(false));
  }, [projectId, navigate]);

  useEffect(() => { fetchAll(); }, [fetchAll]);

  // Quick status change without opening modal
  const moveTask = async (taskId, newStatus) => {
    try {
      await api.patch(`/tasks/${taskId}`, { status: newStatus });
      setTasks(prev => prev.map(t => t.id === taskId ? { ...t, status: newStatus } : t));
    } catch (err) {
      alert('Ошибка обновления задачи');
    }
  };

  const filteredTasks = tasks.filter(t => {
    const matchSearch   = !search || t.title.toLowerCase().includes(search.toLowerCase());
    const matchPriority = filterPriority === 'all' || t.priority === filterPriority;
    const matchAssignee = filterAssignee === 'all' || String(t.assignee_id) === filterAssignee;
    return matchSearch && matchPriority && matchAssignee;
  });

  const byStatus = (status) => filteredTasks.filter(t => t.status === status);

  if (loading) {
    return (
      <div style={{ display: 'flex', justifyContent: 'center', padding: '80px 0' }}>
        <div className="spinner" />
      </div>
    );
  }

  return (
    <div className="board-page">
      {/* Header */}
      <div className="page-header">
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 4 }}>
            <button className="btn btn-ghost btn-sm" onClick={() => navigate('/projects')}>
              ← Проекты
            </button>
            <span style={{ color: 'var(--gray-300)' }}>/</span>
            <h1 className="page-title" style={{ margin: 0 }}>{project?.name}</h1>
          </div>
          {project?.description && (
            <p className="page-subtitle">{project.description}</p>
          )}
        </div>
        <button className="btn btn-primary" onClick={() => setModalTask(null)}>
          + Новая задача
        </button>
      </div>

      {/* Stats row */}
      {stats && (
        <div style={{ display: 'flex', gap: 12, marginBottom: 20, flexWrap: 'wrap' }}>
          {[
            { label: 'Всего',        value: stats.total,      color: 'var(--gray-700)' },
            { label: 'К выполнению', value: stats.todo,       color: 'var(--gray-500)' },
            { label: 'В работе',     value: stats.in_progress,color: '#2563EB' },
            { label: 'Ревью',        value: stats.review,     color: 'var(--orange)'   },
            { label: 'Готово',       value: stats.done,       color: 'var(--green)'    },
            { label: 'Критических',  value: stats.critical,   color: 'var(--red)'      },
            { label: 'Просрочено',   value: stats.overdue,    color: stats.overdue ? 'var(--red)' : 'var(--gray-400)' },
          ].map(({ label, value, color }) => (
            <div key={label} style={{
              background: 'var(--white)', border: '1px solid var(--gray-200)',
              borderRadius: 'var(--radius)', padding: '8px 14px', textAlign: 'center'
            }}>
              <div style={{ fontSize: 20, fontWeight: 700, color }}>{value}</div>
              <div style={{ fontSize: 11, color: 'var(--gray-400)', marginTop: 2 }}>{label}</div>
            </div>
          ))}
        </div>
      )}

      {/* Filters */}
      <div style={{ display: 'flex', gap: 10, marginBottom: 16, flexWrap: 'wrap', alignItems: 'center' }}>
        <input
          className="form-control"
          style={{ maxWidth: 240 }}
          placeholder="🔍 Поиск по задачам..."
          value={search}
          onChange={e => setSearch(e.target.value)}
        />

        <select
          className="form-control"
          style={{ maxWidth: 160 }}
          value={filterPriority}
          onChange={e => setFilterPriority(e.target.value)}
        >
          <option value="all">Все приоритеты</option>
          {PRIORITIES.map(p => (
            <option key={p} value={p}>{PRIORITY_LABELS[p]}</option>
          ))}
        </select>

        <select
          className="form-control"
          style={{ maxWidth: 180 }}
          value={filterAssignee}
          onChange={e => setFilterAssignee(e.target.value)}
        >
          <option value="all">Все исполнители</option>
          {users.map(u => (
            <option key={u.id} value={String(u.id)}>{u.name}</option>
          ))}
        </select>

        {(search || filterPriority !== 'all' || filterAssignee !== 'all') && (
          <button
            className="btn btn-ghost btn-sm"
            onClick={() => { setSearch(''); setFilterPriority('all'); setFilterAssignee('all'); }}
          >
            Сбросить
          </button>
        )}

        <span style={{ fontSize: 12, color: 'var(--gray-400)', marginLeft: 'auto' }}>
          {filteredTasks.length} из {tasks.length} задач
        </span>
      </div>

      {/* Kanban columns */}
      <div className="board-columns">
        {COLUMNS.map(col => {
          const colTasks = byStatus(col.key);
          return (
            <div key={col.key} className="board-column">
              <div className="column-header">
                <div className="column-title">
                  <div className="column-dot" style={{ background: col.color }} />
                  {col.label}
                </div>
                <span className="column-count">{colTasks.length}</span>
              </div>

              <div className="column-cards">
                {colTasks.map(task => (
                  <div key={task.id}>
                    <TaskCard task={task} onClick={setModalTask} />
                    {/* Quick move buttons on hover — shown as small row below card */}
                    <div style={{ display: 'flex', gap: 2, marginTop: 2, opacity: .6 }}>
                      {COLUMNS.filter(c => c.key !== col.key).map(c => (
                        <button
                          key={c.key}
                          className="btn btn-ghost"
                          style={{ fontSize: 9, padding: '1px 5px', flex: 1, color: c.color, borderColor: c.color }}
                          onClick={() => moveTask(task.id, c.key)}
                          title={`Переместить в «${c.label}»`}
                        >
                          → {c.label.split(' ')[0]}
                        </button>
                      ))}
                    </div>
                  </div>
                ))}

                {colTasks.length === 0 && (
                  <div style={{ textAlign: 'center', padding: '20px 10px', color: 'var(--gray-300)', fontSize: 12 }}>
                    Нет задач
                  </div>
                )}

                <button
                  className="btn btn-ghost btn-sm"
                  style={{ width: '100%', marginTop: 4, fontSize: 12, color: 'var(--gray-400)' }}
                  onClick={() => setModalTask(null)}
                >
                  + Добавить задачу
                </button>
              </div>
            </div>
          );
        })}
      </div>

      {/* Task modal */}
      {modalTask !== undefined && (
        <TaskModal
          task={modalTask}
          projectId={parseInt(projectId)}
          users={users}
          onClose={() => setModalTask(undefined)}
          onSaved={fetchAll}
        />
      )}
    </div>
  );
}
