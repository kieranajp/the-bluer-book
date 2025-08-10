import { store } from '../bootstrap.js';

// Pagination window builder (ellipsis strategy matches legacy)
function buildWindow(current, total) {
  const pages = [];

  if (total <= 0) return pages;

  if (total <= 7) {
    for (let i = 1; i <= total; i++) {
      pages.push(i);
    }
    return pages;
  }

  pages.push(1);

  if (current <= 4) {
    for (let i = 2; i <= 5; i++) {
      pages.push(i);
    }
    pages.push('...');
    pages.push(total);
  } else if (current >= total - 3) {
    pages.push('...');
    for (let i = total - 4; i < total; i++) {
      pages.push(i);
    }
    pages.push(total);
  } else {
    pages.push('...');
    for (let i = current - 1; i <= current + 1; i++) {
      pages.push(i);
    }
    pages.push('...');
    pages.push(total);
  }

  return pages;
}

export function Pagination() {
  return {
    get pages() {
      return buildWindow(store.page, store.totalPages);
    },

    get currentPage() {
      return store.page;
    },

    get totalPages() {
      return store.totalPages;
    },

    go(page) {
      if (page === '...' || page === store.page) {
        return;
      }

      if (page < 1 || page > store.totalPages) {
        return;
      }

      store.page = page;

      // Fire a custom event; RecipeList listens (or we can reload directly)
      window.dispatchEvent(new CustomEvent('store:page-changed'));
    },

    next() {
      this.go(store.page + 1);
    },

    prev() {
      this.go(store.page - 1);
    }
  };
}
