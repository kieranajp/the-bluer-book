import { getRecipe, archiveRecipe } from '../api.js';
import { setRecipeTitle, setListTitle } from '../title.js';
import { add as addNotification } from './notifications.js';

const YT_PATTERN = /(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})/;

function isYouTube(url) {
  return !!(url && YT_PATTERN.test(url));
}

function videoId(url) {
  const m = url ? url.match(YT_PATTERN) : null;
  return m ? m[1] : null;
}

function startTime(url) {
  if (!url) return null;

  const m = url.match(/[?&]t=(\d+)/);
  return m ? parseInt(m[1]) : null;
}

function embedUrl(url) {
  const id = videoId(url);
  if (!id) return null;

  const t = startTime(url);
  return t ? `https://www.youtube.com/embed/${id}?start=${t}` : `https://www.youtube.com/embed/${id}`;
}

function displayInfo(url) {
  if (!url) return null;

  if (isYouTube(url)) {
    return {
      type: 'youtube',
      embedUrl: embedUrl(url),
      originalUrl: url,
      icon: '📺',
      label: 'Watch Recipe Video'
    };
  }

  if (url.toLowerCase().includes('.pdf')) {
    return {
      type: 'pdf',
      originalUrl: url,
      icon: '📄',
      label: 'View Recipe PDF'
    };
  }

  try {
    const u = new URL(url);
    return {
      type: 'link',
      originalUrl: url,
      icon: '🔗',
      label: `Visit ${u.hostname}`,
      domain: u.hostname
    };
  } catch {
    return {
      type: 'link',
      originalUrl: url,
      icon: '🔗',
      label: 'View Recipe Source'
    };
  }
}

export function RecipeDetail(store) {
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

    // Expose urlInfo functions for use in the template
    get urlInfo() {
      return {
        displayInfo
      };
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
