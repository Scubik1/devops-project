import React, { useState, useEffect } from 'react';
import api from '../api/axios';
import Modal from '../components/Modal';

function ProjectCard({ project, onClick, onDelete }) {
  const pct = project.task_count
    ? Math.round((project.done_count / project.task_count) * 100)
    : 0;

  const statusColor = {
    active: 'var(--green)',
    archived: 'var(--gray-400)',
    completed: 'var(--mid-blue)',
  }[project.status] || 'var(--gray-400)';

  return (
    <div className="project-card" onClick={onClick}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
        <h3 className="project-name">{project.name}</h3>
        <span
          className="badge"
          style={{ background: `${statusColor}20`, color: statusColor, flexShrink: 0 }}
        >
          {project.status}
        </span>
      </div>

      {project.description && (
        <p className="project-desc">{project.description}</p>
      )}

      <div>
        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, color: 'var(--gray-500)', marginBottom: 6 }}>
          <span>Прогресс</span>
          <span>{pct}% ({project.done_count}/{project.task_count})</span>
        </div>
        <div className="progress-bar">
          <div className="progress-fill" style={{ width: `${pct}%` }} />
        </div>
      </div>

      <div className="project-footer">
        <span>👥 {project.member_count} участников</span>
        <button
          className="btn btn-ghost btn-sm"
          onClick={(e) => { e.stopPropagation(); onDelete(project); }}
          style={{ color: 'var(--red)', borderColor: 'var(--red)', padding: '3px 8px' }}
        >
          Удалить
        </button>
      </div>
    </div>
  );
}

export default function Projects({ navigate }) {
  const [projects, setProjects] = useState([]);
  const [loading, setLoading]   = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState(null);
  const [form, setForm] = useState({ name: '', description: '' });
  const [saving, setSaving] = useState(false);
  const [error, setError]   = useState('');
  const [filter, setFilter] = useState('all');

  const fetchProjects = () => {
    setLoading(true);
    api.get('/projects')
      .then(r => setProjects(r.data))
      .finally(() => setLoading(false));
  };

  useEffect(() => { fetchProjects(); }, []);

  const handleCreate = async (e) => {
    e.preventDefault();
    setError('');
    setSaving(true);
    try {
      await api.post('/projects', form);
      setShowModal(false);
      setForm({ name: '', description: '' });
      fetchProjects();
    } catch (err) {
      setError(err.response?.data?.error || 'Ошибка создания проекта');
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async () => {
    if (!deleteTarget) return;
    try {
      await api.delete(`/projects/${deleteTarget.id}`);
      setDeleteTarget(null);
      fetchProjects();
    } catch (err) {
      alert(err.response?.data?.error || 'Ошибка удаления');
    }
  };

  const filtered = filter === 'all'
    ? projects
    : projects.filter(p => p.status === filter);

  return (
    <div>
      <div className="page-header">
        <div>
          <h1 className="page-title">Проекты</h1>
          <p className="page-subtitle">{projects.length} проектов всего</p>
        </div>
        <button className="btn btn-primary" onClick={() => setShowModal(true)}>
          + Новый проект
        </button>
      </div>

      {/* Filter tabs */}
      <div style={{ display: 'flex', gap: 6, marginBottom: 20 }}>
        {['all', 'active', 'completed', 'archived'].map(f => (
          <button
            key={f}
            className={`btn btn-sm ${filter === f ? 'btn-primary' : 'btn-ghost'}`}
            onClick={() => setFilter(f)}
          >
            {f === 'all' ? 'Все' : f === 'active' ? 'Активные' : f === 'completed' ? 'Завершённые' : 'Архив'}
          </button>
        ))}
      </div>

      {loading ? (
        <div style={{ display: 'flex', justifyContent: 'center', padding: '60px 0' }}>
          <div className="spinner" />
        </div>
      ) : filtered.length === 0 ? (
        <div className="empty-state">
          <h3>Нет проектов</h3>
          <p>Создайте первый проект, нажав кнопку выше</p>
        </div>
      ) : (
        <div className="grid-2">
          {filtered.map(p => (
            <ProjectCard
              key={p.id}
              project={p}
              onClick={() => navigate(`/board/${p.id}`)}
              onDelete={setDeleteTarget}
            />
          ))}
        </div>
      )}

      {/* Create modal */}
      {showModal && (
        <Modal
          title="Новый проект"
          onClose={() => { setShowModal(false); setError(''); }}
          footer={
            <>
              <button className="btn btn-ghost" onClick={() => setShowModal(false)}>Отмена</button>
              <button className="btn btn-primary" form="project-form" type="submit" disabled={saving}>
                {saving ? 'Создание...' : 'Создать'}
              </button>
            </>
          }
        >
          {error && <div className="alert alert-error">{error}</div>}
          <form id="project-form" onSubmit={handleCreate} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
            <div className="form-group">
              <label className="form-label">Название *</label>
              <input
                className="form-control"
                value={form.name}
                onChange={e => setForm(f => ({ ...f, name: e.target.value }))}
                placeholder="Название проекта"
                required
                autoFocus
              />
            </div>
            <div className="form-group">
              <label className="form-label">Описание</label>
              <textarea
                className="form-control"
                value={form.description}
                onChange={e => setForm(f => ({ ...f, description: e.target.value }))}
                placeholder="Краткое описание проекта..."
                rows={3}
              />
            </div>
          </form>
        </Modal>
      )}

      {/* Delete confirm modal */}
      {deleteTarget && (
        <Modal
          title="Удалить проект?"
          onClose={() => setDeleteTarget(null)}
          footer={
            <>
              <button className="btn btn-ghost" onClick={() => setDeleteTarget(null)}>Отмена</button>
              <button className="btn btn-danger" onClick={handleDelete}>Удалить</button>
            </>
          }
        >
          <div className="alert alert-error">
            Вы уверены, что хотите удалить проект <strong>«{deleteTarget.name}»</strong>?
            Все задачи проекта будут удалены безвозвратно.
          </div>
        </Modal>
      )}
    </div>
  );
}
