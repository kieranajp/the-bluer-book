import { add as addNotification } from './notifications.js';

export function LabelFilter(store) {
  return {
    async init() {
      // Extract unique labels from all recipes when component initializes
      this.updateAvailableLabels();

      // Listen for recipe list updates to refresh available labels
      window.addEventListener('store:recipes-updated', () => {
        this.updateAvailableLabels();
      });
    },

    updateAvailableLabels() {
      const labelsSet = new Set();
      store.recipes.forEach(recipe => {
        if (recipe.labels && Array.isArray(recipe.labels)) {
          recipe.labels.forEach(label => {
            if (label.name) labelsSet.add(label.name);
          });
        }
      });
      store.availableLabels = Array.from(labelsSet).sort();
    },

    toggleLabel(labelName) {
      const index = store.selectedLabels.indexOf(labelName);
      if (index === -1) {
        store.selectedLabels.push(labelName);
      } else {
        store.selectedLabels.splice(index, 1);
      }

      // Reset to first page when filtering changes
      store.page = 1;

      // Trigger recipe list refresh
      window.dispatchEvent(new CustomEvent('store:refresh-list'));
    },

    clearAllFilters() {
      store.selectedLabels = [];
      store.page = 1;
      window.dispatchEvent(new CustomEvent('store:refresh-list'));
    },

    get hasActiveFilters() {
      return store.selectedLabels.length > 0;
    },

    get selectedCount() {
      return store.selectedLabels.length;
    }
  };
}
