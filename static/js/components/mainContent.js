import { store } from '../bootstrap.js';

export function MainContent() {
  return {
    // Expose all needed variables from the store
    get loading() {
      return store.loadingList;
    },

    get recipes() {
      return store.recipes;
    },

    get totalPages() {
      return store.totalPages;
    },

    get searchQuery() {
      return store.search;
    },

    get pageSize() {
      return store.pageSize;
    },

    get totalRecipes() {
      return store.total;
    },

    get appStore() {
      return window.appStore;
    }
  };
}
