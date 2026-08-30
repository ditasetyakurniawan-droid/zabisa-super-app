import {create} from 'zustand';
import {api, clearSession, configureSessionExpiredHandler, getSession, signIn, signOut} from '../api/client';
import type {User} from '../types/domain';

type AuthState = {
  user: User | null;
  hydrated: boolean;
  busy: boolean;
  hydrate: () => Promise<void>;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
};

export const useAuth = create<AuthState>((set) => ({
  user: null,
  hydrated: false,
  busy: false,
  hydrate: async () => {
    const session = await getSession();
    if (!session) {
      set({hydrated: true, user: null});
      return;
    }
    try {
      const user = await api<User>('/api/v1/auth/me');
      set({user, hydrated: true});
    } catch {
      await clearSession();
      set({user: null, hydrated: true});
    }
  },
  login: async (email, password) => {
    set({busy: true});
    try {
      const signedInUser = await signIn(email, password);
      // The login contract already returns the authenticated user. Avoid a second
      // request here so login remains resilient on slow mobile connections.
      set({user: signedInUser as User, hydrated: true});
    } finally {
      set({busy: false});
    }
  },
  logout: async () => {
    set({busy: true});
    try {
      await signOut();
      set({user: null});
    } finally {
      set({busy: false});
    }
  },
}));

configureSessionExpiredHandler(() => {
  useAuth.setState({user: null, hydrated: true, busy: false});
});
