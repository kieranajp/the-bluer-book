export function setListTitle() {
  document.title = 'Recipes – The Bluer Book';
}

export function setRecipeTitle(name) {
  document.title = name ? `${name} – The Bluer Book` : 'Recipes – The Bluer Book';
}
