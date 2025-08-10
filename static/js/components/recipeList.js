import { listRecipes, addToMealPlan, removeFromMealPlan } from '../api.js';
import { setListTitle } from '../title.js';
import { add as addNotification } from './notifications.js';
import { derive } from '../store.js';

export function RecipeList(store) {
  return {
    async init() {
      if (!store.recipes.length) {
        await this.load();
      }

      // Listen for refresh events from other components
      window.addEventListener('store:refresh-list', () => {
        this.load();
      });
    },

    get hasMealPlanRecipes() {
      return store.mealPlanItems.length > 0;
    },

    async load() {
      try {
        store.loadingList = true;
        const offset = (store.page - 1) * store.pageSize;

        const { recipes, total } = await listRecipes({
          search: store.search,
          labels: store.selectedLabels, // Include selected labels
          limit: store.pageSize,
          offset
        });

        // Force reactivity by clearing and repopulating the array
        store.recipes.length = 0;
        store.recipes.push(...recipes);

        // Update total - let derive calculate totalPages
        store.total = total;

        // Update derived values including filtered lists and totalPages
        derive(store);

        // Notify that recipes have been updated
        window.dispatchEvent(new CustomEvent('store:recipes-updated'));

        setListTitle();
      } catch (e) {
        // minimal error handling – notifications helper can be used here if desired
        addNotification(store, 'Failed to load recipes');
      } finally {
        store.loadingList = false;
      }
    },

    open(recipe) {
      if (store.router) {
        store.selectedId = recipe.uuid;
        store.router.goToRecipe(recipe.uuid);
      }
    },

    async toggleMealPlan(recipe, event) {
      // Prevent opening recipe when clicking star
      event.stopPropagation();

      try {
        const wasInMealPlan = recipe.isInMealPlan;

        // Optimistic update
        recipe.isInMealPlan = !wasInMealPlan;

        if (wasInMealPlan) {
          await removeFromMealPlan(recipe.uuid);
          addNotification(store, 'Removed from meal plan');
        } else {
          await addToMealPlan(recipe.uuid);
          addNotification(store, 'Added to meal plan');
        }

        // Update cache if recipe is cached
        if (store.recipeCache.has(recipe.uuid)) {
          const cachedRecipe = store.recipeCache.get(recipe.uuid);
          cachedRecipe.isInMealPlan = recipe.isInMealPlan;
        }

      } catch (e) {
        // Revert optimistic update on error
        recipe.isInMealPlan = !recipe.isInMealPlan;
        addNotification(store, 'Failed to update meal plan');
      }
    },

    addLabelFilter(labelName) {
      // Add label to filters if not already present
      if (!store.selectedLabels.includes(labelName)) {
        store.selectedLabels.push(labelName);
        store.page = 1; // Reset to first page
        window.dispatchEvent(new CustomEvent('store:refresh-list'));
      }
    }
  };
}
