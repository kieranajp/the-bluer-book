import { createStore, derive } from './store.js';
import * as notify from './components/notifications.js';
import * as router from './router.js';
import { Pagination } from './components/pagination.js';
import { Notifications as NotificationsComp } from './components/notifications.js';
import { SearchBox } from './components/searchBox.js';
import { RecipeList } from './components/recipeList.js';
import { RecipeDetail } from './components/recipeDetail.js';
import { RecipeEdit } from './components/recipeEdit.js';
import { MainContent } from './components/mainContent.js';
import { LabelFilter } from './components/labelFilter.js';
import { Chat } from './components/chat.js';

async function startApp() {
  let Alpine;
  // Use local package in Node/test (Vitest, JSDOM), CDN only in browser
  if (typeof window === 'undefined') {
    Alpine = (await import('alpinejs')).default;
  } else {
    Alpine = (await import('https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/module.esm.js')).default;
  }

  const store = Alpine.reactive(createStore());
  store.router = router;
  window.appStore = store;

  function updateDerived() { derive(store); }

  Alpine.data('Notifications', () => NotificationsComp(store));
  Alpine.data('Pagination', () => Pagination(store));
  Alpine.data('SearchBox', () => SearchBox(store));
  Alpine.data('RecipeList', () => RecipeList(store));
  Alpine.data('RecipeDetail', () => RecipeDetail(store));
  Alpine.data('RecipeEdit', () => RecipeEdit(store));
  Alpine.data('MainContent', () => MainContent(store));
  Alpine.data('LabelFilter', () => LabelFilter(store));
  Alpine.data('Chat', Chat);

  window.addNotification = function(message, timeout = 4000) {
    return notify.add(store, message, timeout);
  };

  router.initRouter((route) => {
    if (route.name === 'recipe') {
      store.view = 'recipe';
      store.selectedId = route.id;
    } else if (route.name === 'edit') {
      store.view = 'edit';
      store.selectedId = route.id;
    } else {
      store.view = 'list';
      store.selectedId = null;
    }
  });

  Alpine.start();

  async function refreshRecipeList() {
    try {
      const mod = await import('./api.js');
      const { listRecipes } = mod;
      store.loadingList = true;
      const offset = (store.page - 1) * store.pageSize;
      const { recipes, total } = await listRecipes({
        search: store.search,
        labels: store.selectedLabels, // Include selected labels
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

  window.addEventListener('store:page-changed', refreshRecipeList);
  window.addEventListener('store:refresh-list', refreshRecipeList);

  return { store, updateDerived };
}

startApp();
