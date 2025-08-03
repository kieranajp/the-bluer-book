function recipeApp() {
    return {
        // State
        searchQuery: '',
        recipes: [],
        selectedRecipe: null,
        loading: false,

        // Pagination state
        currentPage: 1,
        pageSize: 20,
        totalRecipes: 0,
        totalPages: 0,

        // Initialize
        init() {
            // Load popular recipes on startup
            this.loadRecipes();

            // Set up hash-based routing for permalinks
            this.setupRouting();
        },

        // Set up hash-based routing for recipe permalinks
        setupRouting() {
            // Listen for hash changes (back/forward navigation)
            window.addEventListener('hashchange', () => {
                this.handleHashChange();
            });

            // Listen for modal close events to clear hash
            const modal = document.getElementById('recipeModal');
            if (modal) {
                modal.addEventListener('hidden.bs.modal', () => {
                    // Only clear hash if we're closing due to user action, not due to hash change
                    if (window.location.hash.startsWith('#recipe/')) {
                        history.replaceState(null, null, window.location.pathname + window.location.search);
                    }
                    this.selectedRecipe = null;
                });
            }

            // Check for recipe hash on page load
            this.handleHashChange();
        },

        // Handle hash changes for recipe permalinks
        async handleHashChange() {
            const hash = window.location.hash;
            const recipeMatch = hash.match(/^#recipe\/([a-f0-9-]+)$/);

            if (recipeMatch) {
                const recipeId = recipeMatch[1];
                await this.openRecipeFromHash(recipeId);
            } else {
                // If no recipe hash, close modal if it's open
                if (this.selectedRecipe) {
                    this.closeRecipeModal();
                }
            }
        },

        // Open recipe modal from hash (for permalinks)
        async openRecipeFromHash(recipeId) {
            try {
                const response = await fetch(`/api/recipes/${recipeId}`);
                if (!response.ok) {
                    throw new Error(`Recipe not found: ${response.status}`);
                }

                const recipe = await response.json();
                this.selectedRecipe = recipe;

                // Open modal without updating hash (to prevent loop)
                const modal = new bootstrap.Modal(document.getElementById('recipeModal'));
                modal.show();
            } catch (error) {
                console.error('Failed to load recipe from URL:', error);
                // Clear invalid hash
                window.location.hash = '';
            }
        },

        // Search recipes with debouncing
        async searchRecipes() {
            this.currentPage = 1; // Reset to first page on search

            if (!this.searchQuery.trim()) {
                await this.loadRecipes();
                return;
            }

            this.loading = true;

            try {
                const offset = (this.currentPage - 1) * this.pageSize;
                const response = await fetch(`/api/recipes?search=${encodeURIComponent(this.searchQuery)}&limit=${this.pageSize}&offset=${offset}`);

                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }

                const data = await response.json();
                this.recipes = data.recipes || [];
                this.totalRecipes = data.total || 0;
                this.totalPages = Math.ceil(this.totalRecipes / this.pageSize);
            } catch (error) {
                console.error('Search failed:', error);
                this.recipes = [];
                this.totalRecipes = 0;
                this.totalPages = 0;
                // Could add user-friendly error message here
            } finally {
                this.loading = false;
            }
        },

        // Load recent/popular recipes
        async loadRecipes() {
            this.loading = true;

            try {
                const offset = (this.currentPage - 1) * this.pageSize;
                const response = await fetch(`/api/recipes?limit=${this.pageSize}&offset=${offset}`);

                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }

                const data = await response.json();
                this.recipes = data.recipes || [];
                this.totalRecipes = data.total || 0;
                this.totalPages = Math.ceil(this.totalRecipes / this.pageSize);
            } catch (error) {
                console.error('Load failed:', error);
                this.recipes = [];
                this.totalRecipes = 0;
                this.totalPages = 0;
                // Could add user-friendly error message here
            } finally {
                this.loading = false;
            }
        },

        // Pagination methods
        async goToPage(page) {
            if (page < 1 || page > this.totalPages || page === this.currentPage) {
                return;
            }

            this.currentPage = page;

            if (this.searchQuery.trim()) {
                await this.searchRecipes();
            } else {
                await this.loadRecipes();
            }
        },

        async nextPage() {
            if (this.currentPage < this.totalPages) {
                await this.goToPage(this.currentPage + 1);
            }
        },

        async previousPage() {
            if (this.currentPage > 1) {
                await this.goToPage(this.currentPage - 1);
            }
        },

        // Generate page numbers for pagination controls
        getPageNumbers() {
            const pages = [];
            const total = this.totalPages;
            const current = this.currentPage;

            if (total <= 7) {
                // Show all pages if 7 or fewer
                for (let i = 1; i <= total; i++) {
                    pages.push(i);
                }
            } else {
                // Show windowed pagination
                pages.push(1);

                if (current <= 4) {
                    // Near the beginning
                    for (let i = 2; i <= 5; i++) {
                        pages.push(i);
                    }
                    pages.push('...');
                    pages.push(total);
                } else if (current >= total - 3) {
                    // Near the end
                    pages.push('...');
                    for (let i = total - 4; i < total; i++) {
                        pages.push(i);
                    }
                    pages.push(total);
                } else {
                    // In the middle
                    pages.push('...');
                    for (let i = current - 1; i <= current + 1; i++) {
                        pages.push(i);
                    }
                    pages.push('...');
                    pages.push(total);
                }
            }

            return pages;
        },

        // YouTube URL helpers
        isYouTubeUrl(url) {
            if (!url) return false;
            const youtubeRegex = /(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})/;
            return youtubeRegex.test(url);
        },

        getYouTubeVideoId(url) {
            if (!url) return null;
            const match = url.match(/(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})/);
            return match ? match[1] : null;
        },

        getYouTubeStartTime(url) {
            if (!url) return null;
            const match = url.match(/[?&]t=(\d+)/);
            return match ? parseInt(match[1]) : null;
        },

        getYouTubeEmbedUrl(url) {
            const videoId = this.getYouTubeVideoId(url);
            if (!videoId) return null;

            let embedUrl = `https://www.youtube.com/embed/${videoId}`;
            const startTime = this.getYouTubeStartTime(url);

            if (startTime) {
                embedUrl += `?start=${startTime}`;
            }

            return embedUrl;
        },

        // Get display info for recipe URL
        getUrlDisplayInfo(url) {
            if (!url) return null;

            if (this.isYouTubeUrl(url)) {
                return {
                    type: 'youtube',
                    embedUrl: this.getYouTubeEmbedUrl(url),
                    originalUrl: url,
                    icon: '📺',
                    label: 'Watch Recipe Video'
                };
            }

            // Check if it's a PDF
            if (url.toLowerCase().includes('.pdf')) {
                return {
                    type: 'pdf',
                    originalUrl: url,
                    icon: '📄',
                    label: 'View Recipe PDF'
                };
            }

            // Regular web link
            try {
                const urlObj = new URL(url);
                return {
                    type: 'link',
                    originalUrl: url,
                    icon: '🔗',
                    label: `Visit ${urlObj.hostname}`,
                    domain: urlObj.hostname
                };
            } catch {
                return {
                    type: 'link',
                    originalUrl: url,
                    icon: '🔗',
                    label: 'View Recipe Source'
                };
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

                // Update URL hash for permalink
                window.location.hash = `recipe/${recipe.uuid}`;

                // Show modal
                const modal = new bootstrap.Modal(document.getElementById('recipeModal'));
                modal.show();
            } catch (error) {
                console.error('Failed to load recipe details:', error);
                // Could add user-friendly error message here
            }
        },

        // Close recipe modal and clear hash
        closeRecipeModal() {
            const modal = bootstrap.Modal.getInstance(document.getElementById('recipeModal'));
            if (modal) {
                modal.hide();
            }
            this.selectedRecipe = null;
            // Clear hash without triggering hashchange event
            history.replaceState(null, null, window.location.pathname + window.location.search);
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

                // Close modal and clear hash
                this.closeRecipeModal();

                // Refresh current page to reflect changes
                if (this.searchQuery.trim()) {
                    await this.searchRecipes();
                } else {
                    await this.loadRecipes();
                }

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
