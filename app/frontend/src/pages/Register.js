import React, { useState } from 'react';
import { useAuth } from '../App';
import api from '../api/axios';

export default function Register() {
  const { login } = useAuth();
  const [form, setForm]       = useState({ name: '', email: '', password: '' });
  const [error, setError]     = useState('');
  const [loading, setLoading] = useState(false);

  const handleChange = (e) =>
    setForm((f) => ({ ...f, [e.target.name]: e.target.value }));

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    if (form.password.length < 6) {
      setError('Пароль должен содержать минимум 6 символов');
      return;
    }
    setLoading(true);
    try {
      const { data } = await api.post('/auth/register', form);
      login(data.token, data.user);
    } catch (err) {
      setError(err.response?.data?.error || 'Ошибка регистрации');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="auth-page">
      <div className="auth-card">
        <div className="auth-logo">
          <h1>Dev<span>Tracker</span></h1>
          <p>Создайте свой аккаунт</p>
        </div>

        {error && <div className="alert alert-error">{error}</div>}

        <form className="auth-form" onSubmit={handleSubmit}>
          <div className="form-group">
            <label className="form-label" htmlFor="name">Полное имя</label>
            <input
              id="name"
              className="form-control"
              type="text"
              name="name"
              placeholder="Иван Иванов"
              value={form.name}
              onChange={handleChange}
              required
              autoFocus
            />
          </div>

          <div className="form-group">
            <label className="form-label" htmlFor="email">Email</label>
            <input
              id="email"
              className="form-control"
              type="email"
              name="email"
              placeholder="you@example.com"
              value={form.email}
              onChange={handleChange}
              required
            />
          </div>

          <div className="form-group">
            <label className="form-label" htmlFor="password">Пароль</label>
            <input
              id="password"
              className="form-control"
              type="password"
              name="password"
              placeholder="Минимум 6 символов"
              value={form.password}
              onChange={handleChange}
              required
            />
          </div>

          <button type="submit" className="btn btn-success btn-lg" disabled={loading} style={{ width: '100%', marginTop: 4 }}>
            {loading ? 'Создание...' : 'Создать аккаунт'}
          </button>
        </form>

        <div className="auth-footer">
          Уже есть аккаунт?{' '}
          <a href="#/login">Войти</a>
        </div>
      </div>
    </div>
  );
}
