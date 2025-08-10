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

    // Router / navigation state (History API only)
        updatingFromRoute: false, // guard to avoid URL/state feedback loops
        recipeCache: new Map(), // uuid -> recipe object
        listScrollY: 0,
        lastRequestedRecipeId: null,
    inFlightRecipes: new Map(), // uuid -> promise
    routeError: null, // retained for internal logic but not directly shown; use notifications
    notifications: [], // {id, message, ts}
    loadingRecipe: false,
    currentRouteName: 'list',

        // Initialize
        init() {
            // Assume modern browser (no fallback)
            this.setupHistoryRouting();
        },
        // -----------------------
        // History Router (Phase 1A)
        // -----------------------
        setupHistoryRouting() {
            window.addEventListener('popstate', () => {
                this.handleRouteChange('pop');
            });

            // Modal close -> navigate back to list if we are on a recipe route
            const modal = document.getElementById('recipeModal');
            if (modal) {
                modal.addEventListener('hidden.bs.modal', () => {
                    if (this.getCurrentPathRoute().name === 'recipe') {
                        // navigate back to list preserving current search/page
                        this.navigate(this.buildListUrl(), { replace: false });
                    }
                    this.selectedRecipe = null;
                });
            }

            // Initial route resolution
            this.handleRouteChange('init');
        },

        // Parse current path into a route descriptor
        getCurrentPathRoute() {
            const path = window.location.pathname || '/';
            const recipeMatch = path.match(/^\/recipes\/([a-f0-9-]+)$/);
            if (recipeMatch) {
                return { name: 'recipe', params: { uuid: recipeMatch[1] } };
            }
            // List route (root or anything else we treat as list for now)
            return { name: 'list', params: {} };
        },

        // Build list URL based on current or provided state
        buildListUrl(options = {}) {
            const search = options.search !== undefined ? options.search : this.searchQuery;
            const page = options.page !== undefined ? options.page : this.currentPage;
            const params = new URLSearchParams();
            if (search && search.trim()) params.set('search', search.trim());
            if (page && page > 1) params.set('page', page);
            const qs = params.toString();
            return qs ? `/?${qs}` : '/';
        },

        // Central navigation helper
    navigate(path, { replace = false, state = {} } = {}) {
            const currentFull = window.location.pathname + window.location.search;
            if (currentFull === path) return; // no-op
            if (replace) {
                history.replaceState(state, '', path);
            } else {
                history.pushState(state, '', path);
            }
            this.handleRouteChange('navigate');
        },

        async handleRouteChange(source) {
            const route = this.getCurrentPathRoute();
            this.currentRouteName = route.name;
            if (route.name === 'recipe') {
                this.routeError = null;
                this.updateDocumentTitle('Loading…');
                // Preserve scroll position from list
                if (this.selectedRecipe == null) {
                    this.listScrollY = window.scrollY;
                }
                await this.loadRecipeForRoute(route.params.uuid);
            } else {
                // LIST route
                this.updateDocumentTitle();
                // Deselect recipe for list view display (optional keep in cache)
                this.selectedRecipe = null;
                this.routeError = null; // clear any route errors when on list
                this.syncListStateFromUrl();
                // Restore scroll (only after coming back from recipe)
                requestAnimationFrame(() => {
                    window.scrollTo(0, this.listScrollY || 0);
                });
                // Ensure recipes are loaded (avoid duplicate fetch on initial if already loaded)
                if (!this.recipes.length || source === 'init' || this._listNeedsReload) {
                    await (this.searchQuery.trim() ? this.searchRecipes() : this.loadRecipes());
                }
            }
        },

        syncListStateFromUrl() {
            this.updatingFromRoute = true;
            const params = new URLSearchParams(window.location.search || '');
            const search = params.get('search') || '';
            const pageParam = parseInt(params.get('page'), 10);
            const page = !isNaN(pageParam) && pageParam > 0 ? pageParam : 1;
            let reloadNeeded = false;
            if (search !== this.searchQuery) {
                this.searchQuery = search;
                reloadNeeded = true;
            }
            if (page !== this.currentPage) {
                this.currentPage = page;
                reloadNeeded = true;
            }
            this._listNeedsReload = reloadNeeded;
            this.updatingFromRoute = false;
        },

        async loadRecipeForRoute(uuid) {
            try {
                // Basic UUID v4-ish validation (allow existing format) – 36 chars with hyphens
                const uuidPattern = /^[a-f0-9-]{32,36}$/i;
                if (!uuidPattern.test(uuid)) {
                    this.routeError = 'not-found';
                    this.updateDocumentTitle('Not Found');
                    this.navigate(this.buildListUrl(), { replace: true });
                    this.addNotification('Recipe not found');
                    return;
                }

                if (this.loadingRecipe) return; // guard against rapid duplicate navigations
                this.loadingRecipe = true;
                this.routeError = null;

                // Cache hit
                if (this.recipeCache.has(uuid)) {
                    this.selectedRecipe = this.recipeCache.get(uuid);
                    this.updateDocumentTitle(this.selectedRecipe.name);
                } else {
                    let promise = this.inFlightRecipes.get(uuid);
                    if (!promise) {
                        this.lastRequestedRecipeId = uuid;
                        promise = fetch(`/api/recipes/${uuid}`)
                            .then(res => {
                                if (!res.ok) {
                                    if (res.status === 404) {
                                        throw new Error('NOT_FOUND');
                                    }
                                    throw new Error(`HTTP_${res.status}`);
                                }
                                return res.json();
                            })
                            .then(recipe => {
                                if (this.lastRequestedRecipeId === uuid) {
                                    this.recipeCache.set(uuid, recipe);
                                    return recipe;
                                }
                                return null; // stale
                            })
                            .finally(() => {
                                this.inFlightRecipes.delete(uuid);
                            });
                        this.inFlightRecipes.set(uuid, promise);
                    }
                    const recipe = await promise;
                    if (recipe) {
                        this.selectedRecipe = recipe;
                        this.updateDocumentTitle(recipe.name);
                    } else if (!this.selectedRecipe) {
                        // stale navigation; nothing to do
                        this.updateDocumentTitle();
                        return;
                    }
                }
                // Focus recipe title when loaded for accessibility
                requestAnimationFrame(() => {
                    const titleEl = document.getElementById('recipe-title');
                    if (titleEl) titleEl.focus();
                });
            } catch (err) {
                console.error('Failed to load recipe route:', err);
                if (String(err.message) === 'NOT_FOUND') {
                    this.routeError = 'not-found';
                    this.addNotification('Recipe not found');
                } else {
                    this.routeError = 'load-failed';
                    this.addNotification('Error loading recipe');
                }
                this.updateDocumentTitle(this.routeError === 'not-found' ? 'Not Found' : 'Error');
                // Return to list but preserve ability to show message
                this.navigate(this.buildListUrl(), { replace: true });
            }
                this.loadingRecipe = false;
        },


        updateDocumentTitle(name) {
            if (name) {
                document.title = `${name} – The Bluer Book`;
            } else {
                document.title = 'Recipes – The Bluer Book';
            }
        },

        // Notification helpers
        addNotification(message, timeout = 4000) {
            const id = Date.now() + Math.random();
            this.notifications.push({ id, message, ts: Date.now() });
            if (timeout > 0) {
                setTimeout(() => {
                    this.dismissNotification(id);
                }, timeout);
            }
        },
        dismissNotification(id) {
            this.notifications = this.notifications.filter(n => n.id !== id);
        },
    // (Legacy hash handlers removed – History API only)

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
                // Sync URL after load if using history and not from a route-derived update
                if (!this.updatingFromRoute) {
                    this.navigate(this.buildListUrl({ search: this.searchQuery, page: this.currentPage }), { replace: true });
                }
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
                if (!this.updatingFromRoute) {
                    this.navigate(this.buildListUrl({ search: this.searchQuery, page: this.currentPage }), { replace: true });
                }
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
            // URL sync handled inside search/load; no extra navigate needed
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
                if (this.loadingRecipe) return; // prevent overlap
                // Fetch full recipe details
                const response = await fetch(`/api/recipes/${recipe.uuid}`);

                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }

                this.selectedRecipe = await response.json();
                // Cache it
                this.recipeCache.set(recipe.uuid, this.selectedRecipe);

                // Navigate using History API -> page view
                this.navigate(`/recipes/${recipe.uuid}`);
                this.updateDocumentTitle(this.selectedRecipe.name);
                requestAnimationFrame(() => {
                    const titleEl = document.getElementById('recipe-title');
                    if (titleEl) titleEl.focus();
                });
            } catch (error) {
                console.error('Failed to load recipe details:', error);
                // Could add user-friendly error message here
            }
        },

        // Close recipe modal and clear hash
        closeRecipeModal() {
            // Now used as a generic return to list helper
            this.selectedRecipe = null;
            this.navigate(this.buildListUrl(), { replace: false });
            this.updateDocumentTitle();
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

                // Success notification
                this.addNotification('Recipe archived successfully');

            } catch (error) {
                console.error('Failed to archive recipe:', error);
                this.addNotification('Failed to archive recipe');
            }
        }
    }
}
