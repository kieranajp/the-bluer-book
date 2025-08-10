import { listRecipes, addToMealPlan, removeFromMealPlan } from '../api.js';
import { setListTitle } from '../title.js';
import { add as addNotification } from './notifications.js';

export function RecipeList(store) {
  return {
    async init() {
      if (!store.recipes.length) {
        await this.load();
      }
    },

    get mealPlanItems() {
      return store.recipes.filter(recipe => recipe.isInMealPlan);
    },

    get regularItems() {
      return store.recipes.filter(recipe => !recipe.isInMealPlan);
    },

    get hasMealPlanRecipes() {
      return this.mealPlanItems.length > 0;
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
    }
  };
}
