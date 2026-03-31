import React, { useState, useEffect } from 'react';
import { useAuth } from '../App';
import { StatusBadge, PriorityBadge } from '../components/Badge';
import api from '../api/axios';

function StatCard({ label, value, color, sub }) {
  return (
    <div className="stat-card">
      <div className="stat-label">{label}</div>
      <div className="stat-value" style={{ color }}>{value}</div>
      {sub && <div className="stat-sub">{sub}</div>}
    </div>
  );
}

export default function Dashboard({ navigate }) {
  const { user } = useAuth();
  const [tasks, setTasks]       = useState([]);
  const [projects, setProjects] = useState([]);
  const [loading, setLoading]   = useState(true);

  useEffect(() => {
    Promise.all([
      api.get('/tasks'),
      api.get('/projects'),
    ]).then(([tasksRes, projectsRes]) => {
      setTasks(tasksRes.data);
      setProjects(projectsRes.data);
    }).finally(() => setLoading(false));
  }, []);

  const myTasks     = tasks.filter(t => t.assignee_id === user?.id);
  const todoTasks   = tasks.filter(t => t.status === 'todo');
  const inProgress  = tasks.filter(t => t.status === 'in_progress');
  const doneTasks   = tasks.filter(t => t.status === 'done');
  const overdue     = tasks.filter(t => t.due_date && new Date(t.due_date) < new Date() && t.status !== 'done');
  const critical    = tasks.filter(t => t.priority === 'critical' && t.status !== 'done');

  const recentTasks = [...tasks]
    .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
    .slice(0, 8);

  if (loading) {
    return (
      <div style={{ display: 'flex', justifyContent: 'center', padding: '80px 0' }}>
        <div className="spinner" />
      </div>
    );
  }

  return (
    <div>
      <div className="page-header">
        <div>
          <h1 className="page-title">Дашборд</h1>
          <p className="page-subtitle">Добро пожаловать, {user?.name}</p>
        </div>
      </div>

      {/* Stats */}
      <div className="dashboard-stats">
        <StatCard label="Все задачи"   value={tasks.length}       color="var(--gray-900)" />
        <StatCard label="К выполнению" value={todoTasks.length}   color="var(--gray-600)" />
        <StatCard label="В работе"     value={inProgress.length}  color="#2563EB" />
        <StatCard label="Выполнено"    value={doneTasks.length}   color="var(--green)" />
        <StatCard label="Мои задачи"   value={myTasks.length}     color="var(--mid-blue)" />
        <StatCard label="Просрочено"   value={overdue.length}     color={overdue.length ? 'var(--red)' : 'var(--gray-400)'} />
        <StatCard label="Критических"  value={critical.length}    color={critical.length ? 'var(--red)' : 'var(--gray-400)'} />
        <StatCard label="Проектов"     value={projects.length}    color="var(--purple)" />
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 20 }}>
        {/* Recent tasks */}
        <div className="card">
          <div className="card-header">
            <span className="card-title">Последние задачи</span>
            <button className="btn btn-ghost btn-sm" onClick={() => navigate('/projects')}>
              Все проекты →
            </button>
          </div>
          <div className="card-body">
            {recentTasks.length === 0 ? (
              <div className="empty-state">
                <h3>Нет задач</h3>
                <p>Создайте проект и добавьте первые задачи</p>
              </div>
            ) : (
              <div className="task-list">
                {recentTasks.map(task => (
                  <div
                    key={task.id}
                    className="task-row"
                    onClick={() => navigate(`/board/${task.project_id}`)}
                  >
                    <StatusBadge status={task.status} />
                    <span className="task-row-title">{task.title}</span>
                    <PriorityBadge priority={task.priority} />
                    {task.project_name && (
                      <span className="task-row-project">{task.project_name}</span>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Projects overview */}
        <div className="card">
          <div className="card-header">
            <span className="card-title">Мои проекты</span>
            <button className="btn btn-ghost btn-sm" onClick={() => navigate('/projects')}>
              Все →
            </button>
          </div>
          <div className="card-body">
            {projects.length === 0 ? (
              <div className="empty-state">
                <h3>Нет проектов</h3>
                <p>Перейдите в «Проекты» и создайте первый</p>
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                {projects.slice(0, 6).map(p => {
                  const pct = p.task_count ? Math.round((p.done_count / p.task_count) * 100) : 0;
                  return (
                    <div
                      key={p.id}
                      style={{ cursor: 'pointer' }}
                      onClick={() => navigate(`/board/${p.id}`)}
                    >
                      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 5 }}>
                        <span style={{ fontSize: 13, fontWeight: 500 }}>{p.name}</span>
                        <span style={{ fontSize: 12, color: 'var(--gray-400)' }}>
                          {p.done_count}/{p.task_count} задач
                        </span>
                      </div>
                      <div className="progress-bar">
                        <div className="progress-fill" style={{ width: `${pct}%` }} />
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
