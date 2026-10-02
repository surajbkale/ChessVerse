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

const LS_KEY = 'chessverse_user';

export function persistUser(user: User) {
  try { localStorage.setItem(LS_KEY, JSON.stringify(user)); } catch {}
}

export function clearPersistedUser() {
  try { localStorage.removeItem(LS_KEY); } catch {}
}

export const userAtom = atom<User | null>({
  key: 'user',
  default: selector({
    key: 'user/default',
    get: async () => {
      if (typeof window !== 'undefined') {
        // Step 1: OAuth redirect — backend puts token/id/name in URL params
        const params = new URLSearchParams(window.location.search);
        const token = params.get('token');
        const id = params.get('id');
        const name = params.get('name');
        if (token && id) {
          const user: User = { token, id, name: name ?? '' };
          // Clean up URL without page reload
          window.history.replaceState({}, '', window.location.pathname);
          persistUser(user);
          return user;
        }

        // Step 2: Page reload — restore from localStorage
        try {
          const stored = localStorage.getItem(LS_KEY);
          if (stored) return JSON.parse(stored) as User;
        } catch {}
      }

      // Step 3: Fallback — session cookie (works for same-origin / guest cookie)
      try {
        const response = await fetch(`${_backendUrl}/auth/refresh`, {
          method: 'GET',
          headers: { 'Content-Type': 'application/json' },
          credentials: 'include',
        });
        if (response.ok) {
          const data = await response.json();
          if (data) persistUser(data);
          return data;
        }
      } catch (e) {
        console.error(e);
      }

      return null;
    },
  }),
});
