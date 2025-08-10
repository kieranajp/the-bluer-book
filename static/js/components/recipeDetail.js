import { store } from '../bootstrap.js';
import { getRecipe, archiveRecipe } from '../api.js';
import { setRecipeTitle, setListTitle } from '../title.js';
import { add as addNotification } from '../notifications.js';

export function RecipeDetail() {
  return {
    async init() {
      // Load recipe if we have a selectedId on init
      if (store.selectedId) {
        await this.load();
      }
    },

    async load() {
      if (!store.selectedId) {
        return;
      }

      try {
        store.loadingRecipe = true;

        if (store.recipeCache.has(store.selectedId)) {
          store.selectedRecipe = store.recipeCache.get(store.selectedId);
          setRecipeTitle(store.selectedRecipe.name);
        } else {
          const recipe = await getRecipe(store.selectedId);
          store.recipeCache.set(store.selectedId, recipe);
          store.selectedRecipe = recipe;
          setRecipeTitle(recipe.name);
        }
      } catch (e) {
        addNotification(store, 'Error loading recipe');
        setListTitle();
      } finally {
        store.loadingRecipe = false;
      }
    },

    get recipe() {
      return store.selectedRecipe;
    },

    get loadingRecipe() {
      return store.loadingRecipe;
    },

    // Watch for changes to selectedId and load the new recipe
    get selectedId() {
      return store.selectedId;
    },

    back() {
      if (store.router) {
        store.router.goToList({ search: store.search, page: store.page });
      }
      setListTitle();
    },

    async archive() {
      if (!store.selectedRecipe) {
        return;
      }

      if (!confirm(`Archive "${store.selectedRecipe.name}"?`)) {
        return;
      }

      try {
        await archiveRecipe(store.selectedRecipe.uuid);
        addNotification(store, 'Recipe archived');
        store.selectedRecipe = null;
        store.router.goToList({ search: store.search, page: store.page, replace: true });

        // Trigger list refresh event for list component to handle
        window.dispatchEvent(new CustomEvent('store:refresh-list'));
      } catch {
        addNotification(store, 'Failed to archive recipe');
      }
    }
  };
}
