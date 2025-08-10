import { listRecipes } from '../api.js';
import { setListTitle } from '../title.js';
import { derive } from '../store.js';

export function SearchBox(store) {
  return {
    get value() {
      return store.search;
    },

    set value(v) {
      store.search = v;
      // Remove auto-search on keypress
    },

    // Manual search trigger (for Enter key or search button)
    async search() {
      store.page = 1;

      try {
        store.loadingList = true;
        const { recipes, total } = await listRecipes({
          search: store.search,
          labels: store.selectedLabels, // Include selected labels
          limit: store.pageSize,
          offset: 0
        });
        store.recipes = recipes;
        store.total = total;

        // Update derived values including filtered lists and totalPages
        derive(store);

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
