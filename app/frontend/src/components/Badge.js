import React from 'react';

const STATUS_LABELS = {
  todo:        'К выполнению',
  in_progress: 'В работе',
  review:      'Ревью',
  done:        'Готово',
};

const PRIORITY_LABELS = {
  low:      'Низкий',
  medium:   'Средний',
  high:     'Высокий',
  critical: 'Критический',
};

export function StatusBadge({ status }) {
  return (
    <span className={`badge badge-${status}`}>
      {STATUS_LABELS[status] || status}
    </span>
  );
}

export function PriorityBadge({ priority }) {
  return (
    <span className={`badge badge-${priority}`}>
      {PRIORITY_LABELS[priority] || priority}
    </span>
  );
}
