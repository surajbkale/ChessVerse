import { PuzzleIcon, LogInIcon, LogOutIcon, SettingsIcon } from 'lucide-react';
import { clearPersistedUser } from '@repo/store/userAtom';

const BACKEND_URL = import.meta.env.VITE_APP_BACKEND_URL ?? '';

export const UpperNavItems = [
  {
    title: 'Play',
    icon: PuzzleIcon,
    href: '/game/random',
    color: 'text-green-500',
  },
];

export const LowerNavItems = [
  {
    title: 'Login',
    icon: LogInIcon,
    href: '/login',
    color: 'text-green-500',
  },
  {
    title: 'Logout',
    icon: LogOutIcon,
    href: '#',
    color: 'text-green-500',
    isLogout: true,
  },
  {
    title: 'Settings',
    icon: SettingsIcon,
    href: '/settings',
    color: 'text-green-500',
  },
];

// Call this on logout button click — clears local state then calls backend
export async function handleLogout(setUser: (u: null) => void) {
  // 1. Clear localStorage and Recoil state immediately
  clearPersistedUser();
  setUser(null);

  // 2. Tell the backend to destroy the session (fire-and-forget, best effort)
  try {
    await fetch(`${BACKEND_URL}/auth/logout`, {
      method: 'GET',
      credentials: 'include',
    });
  } catch (_) {}

  // 3. Navigate to login
  window.location.href = '/login';
}
