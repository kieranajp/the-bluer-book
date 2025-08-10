import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'jsdom',
    include: ['static/js/__tests__/**/*.test.js'],
  },
});
