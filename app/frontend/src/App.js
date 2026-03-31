import React, { useState, useEffect, createContext, useContext } from 'react';
import './styles/App.css';
import api from './api/axios';

import Login    from './pages/Login';
import Register from './pages/Register';
import Dashboard from './pages/Dashboard';
import Projects  from './pages/Projects';
import Board     from './pages/Board';
import Navbar    from './components/Navbar';

// ── Auth Context ─────────────────────────────────────────
export const AuthContext = createContext(null);
export const useAuth = () => useContext(AuthContext);

// ── Simple client-side router (no react-router dep) ──────
function useRoute() {
  const [path, setPath] = useState(window.location.hash.slice(1) || '/');

  useEffect(() => {
    const handler = () => setPath(window.location.hash.slice(1) || '/');
    window.addEventListener('hashchange', handler);
    return () => window.removeEventListener('hashchange', handler);
  }, []);

  const navigate = (to) => {
    window.location.hash = to;
  };

  return { path, navigate };
}

// ── App ──────────────────────────────────────────────────
export default function App() {
  const { path, navigate } = useRoute();
  const [user, setUser]   = useState(null);
  const [loading, setLoading] = useState(true);

  // Restore session from localStorage
  useEffect(() => {
    const token = localStorage.getItem('token');
    const saved = localStorage.getItem('user');
    if (token && saved) {
      setUser(JSON.parse(saved));
      api.defaults.headers.common['Authorization'] = `Bearer ${token}`;
    }
    setLoading(false);
  }, []);

  const login = (token, userData) => {
    localStorage.setItem('token', token);
    localStorage.setItem('user', JSON.stringify(userData));
    api.defaults.headers.common['Authorization'] = `Bearer ${token}`;
    setUser(userData);
    navigate('/dashboard');
  };

  const logout = () => {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    delete api.defaults.headers.common['Authorization'];
    setUser(null);
    navigate('/login');
  };

  if (loading) {
    return (
      <div className="splash">
        <div className="spinner" />
      </div>
    );
  }

  // ── Routing ────────────────────────────────────────────
  const renderPage = () => {
    if (!user) {
      if (path === '/register') return <Register />;
      return <Login />;
    }

    if (path.startsWith('/board/')) {
      const projectId = path.split('/')[2];
      return <Board projectId={projectId} navigate={navigate} />;
    }

    if (path === '/projects') return <Projects navigate={navigate} />;
    return <Dashboard navigate={navigate} />;
  };

  return (
    <AuthContext.Provider value={{ user, login, logout }}>
      <div className="app">
        {user && <Navbar navigate={navigate} currentPath={path} />}
        <main className="main-content">
          {renderPage()}
        </main>
      </div>
    </AuthContext.Provider>
  );
}
