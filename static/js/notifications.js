/** Notification helpers */
export function add(store, message, timeout = 4000) {
  const id = Date.now() + Math.random();
  store.notifications.push({ id, message, ts: Date.now() });

  if (timeout > 0) {
    setTimeout(() => dismiss(store, id), timeout);
  }

  return id;
}

export function dismiss(store, id) {
  const idx = store.notifications.findIndex(n => n.id === id);

  if (idx !== -1) {
    store.notifications.splice(idx, 1);
  }
}
