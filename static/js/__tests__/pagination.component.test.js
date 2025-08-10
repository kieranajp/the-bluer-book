import { describe, it, expect } from 'vitest';
import { Pagination } from '../components/pagination.js';

// Minimal Alpine component factory test (no DOM)
describe('Pagination Alpine component', () => {
  it('returns correct pages for default store state', () => {
    // Mock store state
    const testStore = {
      page: 1,
      totalPages: 5
    };
    const comp = Pagination(testStore);
    expect(comp.pages).toEqual([1,2,3,4,5]);
  });

  it('go() dispatches event for valid page', () => {
    const testStore = { page: 1, totalPages: 5 };
    const comp = Pagination(testStore);
    let called = false;
    window.addEventListener('store:page-changed', () => { called = true; }, { once: true });
    comp.go(2);
    expect(testStore.page).toBe(2);
    expect(called).toBe(true);
  });
});
