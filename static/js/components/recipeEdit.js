import { getRecipe, updateRecipe } from '../api.js';
import { setRecipeTitle, setListTitle } from '../title.js';
import { add as addNotification } from './notifications.js';

export function RecipeEdit(store) {
  return {
    recipe: null,
    originalRecipe: null,
    loadingRecipe: false,
    saving: false,
    lastLoadedId: null,

    async init() {
      if (store.selectedId && store.selectedId !== this.lastLoadedId) {
        await this.load();
      }
    },

    async load() {
      if (!store.selectedId) {
        return;
      }
      
      this.lastLoadedId = store.selectedId;
      
      try {
        this.loadingRecipe = true;
        const recipe = await getRecipe(store.selectedId);
        this.originalRecipe = recipe;
        
        // Create editable copy with proper structure
        this.recipe = JSON.parse(JSON.stringify(recipe));
        
        // Ensure arrays exist
        if (!this.recipe.ingredients) {
          this.recipe.ingredients = [];
        }
        if (!this.recipe.steps) {
          this.recipe.steps = [];
        }
        if (!this.recipe.labels) {
          this.recipe.labels = [];
        }
        
        setRecipeTitle(`Editing: ${recipe.name}`);
      } catch (e) {
        if (e.status === 404) {
          addNotification(store, 'Recipe not found');
          store.router.goToList({ search: store.search, page: store.page, replace: true });
        } else {
          addNotification(store, 'Failed to load recipe');
        }
        setListTitle();
      } finally {
        this.loadingRecipe = false;
      }
    },

    get selectedId() {
      return store.selectedId;
    },

    back() {
      if (store.router) {
        store.router.goToRecipe(store.selectedId);
      }
    },

    addIngredient() {
      if (!this.recipe.ingredients) {
        this.recipe.ingredients = [];
      }
      this.recipe.ingredients.push({
        ingredient: { name: '' },
        unit: { name: '', abbreviation: '' },
        quantity: 0,
        preparation: ''
      });
    },

    removeIngredient(index) {
      this.recipe.ingredients.splice(index, 1);
    },

    addStep() {
      if (!this.recipe.steps) {
        this.recipe.steps = [];
      }
      const nextOrder = this.recipe.steps.length > 0 
        ? Math.max(...this.recipe.steps.map(s => s.order)) + 1 
        : 1;
      this.recipe.steps.push({
        order: nextOrder,
        description: '',
        photos: []
      });
    },

    removeStep(index) {
      this.recipe.steps.splice(index, 1);
      // Reorder remaining steps
      this.recipe.steps.forEach((step, i) => {
        step.order = i + 1;
      });
    },

    addLabel() {
      if (!this.recipe.labels) {
        this.recipe.labels = [];
      }
      this.recipe.labels.push({
        name: '',
        color: '#007bff'
      });
    },

    removeLabel(index) {
      this.recipe.labels.splice(index, 1);
    },

    async save() {
      if (!this.recipe || this.saving) {
        return;
      }

      // Basic validation
      if (!this.recipe.name || !this.recipe.name.trim()) {
        addNotification(store, 'Recipe name is required');
        return;
      }

      try {
        this.saving = true;
        const updatedRecipe = await updateRecipe(store.selectedId, this.recipe);
        
        // Update cache
        store.recipeCache.set(store.selectedId, updatedRecipe);
        store.selectedRecipe = updatedRecipe;
        
        addNotification(store, 'Recipe updated successfully');
        store.router.goToRecipe(store.selectedId, { replace: true });
      } catch (e) {
        addNotification(store, 'Failed to update recipe');
      } finally {
        this.saving = false;
      }
    }
  };
}
