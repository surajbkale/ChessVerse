import { atom, selector } from 'recoil';

// Set this once at app startup via setBackendUrl() before Recoil initializes.
// The store package cannot use import.meta.env directly (Vite-specific).
let _backendUrl = '';

export function setBackendUrl(url: string) {
  _backendUrl = url;
}

export interface User {
  token: string;
  id: string;
  name: string;
}

export const userAtom = atom<User | null>({
  key: 'user',
  default: selector({
    key: 'user/default',
    get: async () => {
      try {
        const response = await fetch(`${_backendUrl}/auth/refresh`, {
          method: 'GET',
          headers: {
            'Content-Type': 'application/json',
          },
          credentials: 'include',
        });
        if (response.ok) {
          const data = await response.json();
          return data;
        }
      } catch (e) {
        console.error(e);
      }

      return null;
    },
  }),
});
