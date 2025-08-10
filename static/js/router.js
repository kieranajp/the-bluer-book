import { setListTitle, setRecipeTitle } from './title.js';

export function parseLocation() {
  const path = window.location.pathname || '/';
  const editMatch = path.match(/^\/recipes\/([a-f0-9-]+)\/edit$/);
  const recipeMatch = path.match(/^\/recipes\/([a-f0-9-]+)$/);

  if (editMatch) {
    return { name: 'edit', id: editMatch[1] };
  }
  if (recipeMatch) {
    return { name: 'recipe', id: recipeMatch[1] };
  }
  return { name: 'list' };
}

export function buildListUrl({ search = '', page = 1 } = {}) {
  const params = new URLSearchParams();
  if (search && search.trim()) params.set('search', search.trim());
  if (page && page > 1) params.set('page', page);
  const qs = params.toString();
  return qs ? `/?${qs}` : '/';
}

function push(path, replace) {
  if ((window.location.pathname + window.location.search) === path) return;
  if (replace) history.replaceState({}, '', path); else history.pushState({}, '', path);
  window.dispatchEvent(new Event('router:navigate'));
}

export function goToList({ search, page, replace = false } = {}) {
  push(buildListUrl({ search, page }), replace);
  setListTitle();
}

export function goToRecipe(id, { replace = false } = {}) {
  push(`/recipes/${id}`, replace);
  setRecipeTitle('Loading…');
}

export function goToEdit(id, { replace = false } = {}) {
  push(`/recipes/${id}/edit`, replace);
  setRecipeTitle('Editing…');
}

export function initRouter(onChange) {
  window.addEventListener('popstate', () => onChange(parseLocation()));
  window.addEventListener('router:navigate', () => onChange(parseLocation()));
  // initial
  onChange(parseLocation());
}
