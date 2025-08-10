import { listRecipes } from '../api.js';
import { setListTitle } from '../title.js';

let debounceTimer;

export function SearchBox(store) {
  return {
    get value() {
      return store.search;
    },

    set value(v) {
      store.search = v;
      this.queue();
    },

    queue() {
      clearTimeout(debounceTimer);
      debounceTimer = setTimeout(() => this.execute(), 300);
    },

    async execute() {
      store.page = 1;

      try {
        store.loadingList = true;
        const { recipes, total } = await listRecipes({
          search: store.search,
          limit: store.pageSize,
          offset: 0
        });
        store.recipes = recipes;
        store.total = total;
        store.totalPages = Math.ceil(total / store.pageSize) || 0;

        if (store.router) {
          store.router.goToList({ search: store.search, page: 1, replace: true });
        }

        setListTitle();
      } finally {
        store.loadingList = false;
      }
    }
  };
}
