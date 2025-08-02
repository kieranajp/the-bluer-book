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
        },

        // Archive recipe with confirmation
        async archiveRecipe() {
            if (!this.selectedRecipe) {
                return;
            }

            const confirmed = confirm(`Are you sure you want to archive "${this.selectedRecipe.name}"?\n\nThis will remove it from your active recipes but keep it for reference.`);

            if (!confirmed) {
                return;
            }

            try {
                const response = await fetch(`/api/recipes/${this.selectedRecipe.uuid}`, {
                    method: 'DELETE',
                    headers: {
                        'Content-Type': 'application/json'
                    }
                });

                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }

                // Close modal
                const modal = bootstrap.Modal.getInstance(document.getElementById('recipeModal'));
                modal.hide();

                // Remove recipe from current list
                this.recipes = this.recipes.filter(r => r.uuid !== this.selectedRecipe.uuid);
                this.selectedRecipe = null;

                // Show success message (simple alert for now)
                alert('Recipe archived successfully!');

            } catch (error) {
                console.error('Failed to archive recipe:', error);
                alert('Failed to archive recipe. Please try again.');
            }
        }
    }
}
