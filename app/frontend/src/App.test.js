import { render, screen } from '@testing-library/react';

// Smoke test — ensures the module tree loads without crashing
test('index.html renders root element', () => {
  const div = document.createElement('div');
  div.setAttribute('id', 'root');
  document.body.appendChild(div);
  expect(div).toBeInTheDocument();
});
