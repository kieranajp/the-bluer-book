import Alpine from 'alpinejs';
import { createStore, derive } from './store.js';
import * as notify from './components/notifications.js';
import * as router from './router.js';
import { Pagination } from './components/pagination.js';
import { Notifications as NotificationsComp } from './components/notifications.js';
import { SearchBox } from './components/searchBox.js';
import { RecipeList } from './components/recipeList.js';
import { RecipeDetail } from './components/recipeDetail.js';
import { MainContent } from './components/mainContent.js';

// Phase 1 bootstrap: create shared store and expose for inspection.
const store = Alpine.reactive(createStore());
store.router = router; // debug reference
window.appStore = store; // temporary debug handle during migration

// Simple watch to keep derived values up to date (manual trigger points will call derive())
function updateDerived() {
  derive(store);
}

// Register Alpine.js components
Alpine.data('Notifications', () => NotificationsComp());
Alpine.data('Pagination', () => Pagination());
Alpine.data('SearchBox', () => SearchBox());
Alpine.data('RecipeList', () => RecipeList());
Alpine.data('RecipeDetail', () => RecipeDetail());
Alpine.data('MainContent', () => MainContent());

// Placeholder util for legacy bridging: add notification
window.addNotification = function(message, timeout = 4000) {
  return notify.add(store, message, timeout);
};

// Initialize router (migration callback updates basic top-level view state only for now)
router.initRouter((route) => {
  if (route.name === 'recipe') {
    store.view = 'recipe';
    store.selectedId = route.id;
  } else {
    store.view = 'list';
    store.selectedId = null;
  }
});

Alpine.start();

// Helper function to refresh the recipe list
async function refreshRecipeList() {
  try {
    const mod = await import('./api.js');
    const { listRecipes } = mod;
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
  } catch (e) {
    // swallow for now
  } finally {
    store.loadingList = false;
  }
}

// Lightweight event-driven reloads (decoupled from legacy app.js)
window.addEventListener('store:page-changed', refreshRecipeList);
window.addEventListener('store:refresh-list', refreshRecipeList);

export { store, updateDerived };
