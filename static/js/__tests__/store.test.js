import { describe, it, expect } from 'vitest'
import { createStore, derive } from '../store.js';

describe('store.js', () => {
  it('creates a default store', () => {
    const store = createStore();
    expect(store.search).toBe('');
    expect(store.recipes).toEqual([]);
    expect(store.page).toBe(1);
    expect(store.totalPages).toBe(0);
  });

  it('derives totalPages correctly', () => {
    const store = createStore();
    store.total = 42;
    store.pageSize = 20;
    derive(store);
    expect(store.totalPages).toBe(3);
  });
});
