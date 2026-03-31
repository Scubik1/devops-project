import React from 'react';
import { useAuth } from '../App';

export default function Navbar({ navigate, currentPath }) {
  const { user, logout } = useAuth();

  const initials = user?.name
    ? user.name.split(' ').map(w => w[0]).join('').toUpperCase().slice(0, 2)
    : '?';

  const links = [
    { label: 'Дашборд', path: '/dashboard' },
    { label: 'Проекты',  path: '/projects' },
  ];

  return (
    <nav className="navbar">
      <span className="navbar-brand" onClick={() => navigate('/dashboard')}>
        Dev<span>Tracker</span>
      </span>

      <ul className="navbar-nav">
        {links.map(({ label, path }) => (
          <li key={path}>
            <span
              className={`nav-link ${currentPath === path ? 'active' : ''}`}
              onClick={() => navigate(path)}
            >
              {label}
            </span>
          </li>
        ))}
      </ul>

      <div className="navbar-right">
        <div className="user-chip">
          <div className="avatar" title={user?.name}>{initials}</div>
          <span style={{ fontSize: 13, color: 'rgba(255,255,255,.85)' }}>{user?.name}</span>
        </div>
        <button className="btn btn-ghost btn-sm" style={{ color: 'rgba(255,255,255,.7)', borderColor: 'rgba(255,255,255,.2)' }} onClick={logout}>
          Выйти
        </button>
      </div>
    </nav>
  );
}
