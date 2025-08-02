function recipeApp() {
    return {
        // State
        searchQuery: '',
        recipes: [],
        selectedRecipe: null,
        loading: false,

        // Initialize
        init() {
            // Load popular recipes on startup
            this.loadRecipes();
        },

        // Search recipes with debouncing
        async searchRecipes() {
            if (!this.searchQuery.trim()) {
                await this.loadRecipes();
                return;
            }

            this.loading = true;

            try {
                const response = await fetch(`/api/recipes?search=${encodeURIComponent(this.searchQuery)}&limit=20`);

                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }

                const data = await response.json();
                this.recipes = data.recipes || [];
            } catch (error) {
                console.error('Search failed:', error);
                this.recipes = [];
                // Could add user-friendly error message here
            } finally {
                this.loading = false;
            }
        },

        // Load recent/popular recipes
        async loadRecipes() {
            this.loading = true;

            try {
                const response = await fetch('/api/recipes?limit=20');

                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }

                const data = await response.json();
                this.recipes = data.recipes || [];
            } catch (error) {
                console.error('Load failed:', error);
                this.recipes = [];
                // Could add user-friendly error message here
            } finally {
                this.loading = false;
            }
        },

        // Show recipe detail modal
        async showRecipeDetail(recipe) {
            try {
                // Fetch full recipe details
                const response = await fetch(`/api/recipes/${recipe.uuid}`);

                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }

                this.selectedRecipe = await response.json();

                // Show modal
                const modal = new bootstrap.Modal(document.getElementById('recipeModal'));
                modal.show();
            } catch (error) {
                console.error('Failed to load recipe details:', error);
                // Could add user-friendly error message here
            }
        }
    }
}
