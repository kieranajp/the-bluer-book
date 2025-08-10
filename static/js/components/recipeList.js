import { listRecipes } from '../api.js';
import { setListTitle } from '../title.js';

export function RecipeList(store) {
  return {
    async init() {
      if (!store.recipes.length) {
        await this.load();
      }
    },

    get items() {
      return store.recipes;
    },

    async load() {
      try {
        store.loadingList = true;
        const offset = (store.page - 1) * store.pageSize;
        const { recipes, total } = await listRecipes({
          search: store.search,
          limit: store.pageSize,
          offset
        });
        store.recipes = recipes;
        store.total = total;
        store.totalPages = Math.ceil(total / store.pageSize) || 0;
        setListTitle();
      } catch (e) {
        // minimal error handling – notifications helper can be used here if desired
      } finally {
        store.loadingList = false;
      }
    },

    open(recipe) {
      if (store.router) {
        store.selectedId = recipe.uuid;
        store.router.goToRecipe(recipe.uuid);
      }
    }
  };
}
