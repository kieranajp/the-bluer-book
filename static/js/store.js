/**
 * Application central state factory.
 * This store is framework-agnostic; Alpine integration happens in bootstrap.js.
 * Fields mirror existing app.js state to enable gradual migration.
 */
export function createStore() {
  return {
    // List / search
    search: '',
    recipes: [],
    total: 0,
    page: 1,
    pageSize: 20,
    totalPages: 0,

    // View / routing
    view: 'list', // 'list' | 'recipe' | 'edit'
    selectedId: null,
    selectedRecipe: null,
    routeError: null,

    // Meal planning
    mealPlanRecipes: [],
    loadingMealPlan: false,

    // Derived recipe lists (updated when recipes change)
    mealPlanItems: [],      // Filtered recipes that are in meal plan
    regularItems: [],       // Filtered recipes that are not in meal plan

    // Label filtering
    selectedLabels: [],     // Array of selected label names for filtering
    availableLabels: [],    // Array of all available labels from recipes

    // Loading flags
    loadingList: false,
    loadingRecipe: false,

    // Notifications
    notifications: [], // { id:number, message:string, ts:number }

    // Caching & in-flight tracking
    recipeCache: new Map(), // uuid -> recipe
    inFlight: new Map(),    // uuid -> Promise

    // Scroll positions per view
    scrollPositions: { list: 0 },

    // Internal flags (migration bridging)
    updatingFromRoute: false,
  };
}

/**
 * Convenience helper to compute derived values; can expand later.
 */
export function derive(store) {
  store.totalPages = Math.ceil((store.total || 0) / store.pageSize) || 0;

  // Update filtered recipe lists
  store.mealPlanItems = store.recipes.filter(recipe => recipe.isInMealPlan);
  store.regularItems = store.recipes.filter(recipe => !recipe.isInMealPlan);
}
