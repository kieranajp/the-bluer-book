/**
 * API wrapper module for recipe operations.
 * All functions throw on non-2xx responses.
 */

async function handle(res) {
  if (!res.ok) {
    const err = new Error(`HTTP_${res.status}`);
    err.status = res.status;
    throw err;
  }
  return res.json();
}

async function handleNoContent(res) {
  if (!res.ok) {
    const err = new Error(`HTTP_${res.status}`);
    err.status = res.status;
    throw err;
  }
  // No JSON parsing for 204 No Content responses
  return true;
}

export async function listRecipes({ search = '', labels = [], limit = 20, offset = 0 } = {}) {
  const qs = new URLSearchParams();
  if (search && search.trim()) qs.set('search', search.trim());
  if (labels && labels.length > 0) qs.set('labels', labels.join(','));
  qs.set('limit', limit);
  qs.set('offset', offset);
  const res = await fetch(`/api/recipes?${qs.toString()}`);
  const data = await handle(res);
  return {
    recipes: Array.isArray(data.recipes) ? data.recipes : [],
    total: typeof data.total === 'number' ? data.total : (data.recipes?.length || 0)
  };
}

export async function getRecipe(uuid) {
  const res = await fetch(`/api/recipes/${uuid}`);
  try {
    return await handle(res);
  } catch (e) {
    if (e.status === 404) {
      const notFound = new Error('NOT_FOUND');
      notFound.status = 404;
      throw notFound;
    }
    throw e;
  }
}

export async function archiveRecipe(uuid) {
  const res = await fetch(`/api/recipes/${uuid}`, { method: 'DELETE', headers: { 'Content-Type': 'application/json' } });
  await handleNoContent(res); // no body expected
  return true;
}

export async function updateRecipe(uuid, recipe) {
  const res = await fetch(`/api/recipes/${uuid}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(recipe)
  });
  return await handle(res);
}

export async function addToMealPlan(uuid) {
  const res = await fetch(`/api/recipes/${uuid}/meal-plan`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' }
  });
  await handleNoContent(res); // no body expected
  return true;
}

export async function removeFromMealPlan(uuid) {
  const res = await fetch(`/api/recipes/${uuid}/meal-plan`, {
    method: 'DELETE',
    headers: { 'Content-Type': 'application/json' }
  });
  await handleNoContent(res); // no body expected
  return true;
}
