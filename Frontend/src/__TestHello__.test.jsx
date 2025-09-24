import React from 'react';
import { render, screen } from '@testing-library/react';
import TestHello from './__TestHello__';
test('renders Hello-Dev', () => { render(<TestHello/>); expect(screen.getByTestId('hello').textContent).toBe('Hello-Dev'); });
