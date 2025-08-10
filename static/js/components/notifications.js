import { store } from '../bootstrap.js';
import { dismiss } from '../notifications.js';

export function Notifications() {
  return {
    get items() {
      return store.notifications;
    },

    dismiss(id) {
      dismiss(store, id);
    }
  };
}
