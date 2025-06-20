import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import App from '../App';

describe('App Component', () => {
  it('renders the heading', () => {
    render(<App />);
    expect(screen.getByText(/Proyecto XAS/i)).toBeDefined();
  });
});
