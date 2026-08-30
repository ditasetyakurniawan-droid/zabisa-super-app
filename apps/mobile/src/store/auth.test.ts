import {beforeEach, describe, expect, it, jest} from '@jest/globals';

jest.mock('../api/client', () => ({
  api: jest.fn(),
  clearSession: jest.fn(),
  configureSessionExpiredHandler: jest.fn(),
  getSession: jest.fn(),
  signIn: jest.fn(),
  signOut: jest.fn(),
}));

import {getSession, signIn, signOut} from '../api/client';
import {useAuth} from './auth';

const mockedGetSession = jest.mocked(getSession);
const mockedSignIn = jest.mocked(signIn);
const mockedSignOut = jest.mocked(signOut);

const guardian = {id: 'guardian-1', email: 'guardian@zabisa.local', name: 'Wali Demo', role: 'GUARDIAN', status: 'ACTIVE'};

describe('auth store', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    useAuth.setState({user: null, hydrated: false, busy: false});
  });

  it('hydrates to a signed-out state when secure storage is empty', async () => {
    mockedGetSession.mockResolvedValue(null);
    await useAuth.getState().hydrate();
    expect(useAuth.getState()).toMatchObject({user: null, hydrated: true, busy: false});
  });

  it('stores the authenticated user returned by login', async () => {
    mockedSignIn.mockResolvedValue(guardian);
    await useAuth.getState().login('guardian@zabisa.local', 'secret');
    expect(useAuth.getState().user).toEqual(guardian);
    expect(useAuth.getState().busy).toBe(false);
  });

  it('clears the local user after logout', async () => {
    useAuth.setState({user: guardian, hydrated: true});
    mockedSignOut.mockResolvedValue(undefined);
    await useAuth.getState().logout();
    expect(useAuth.getState().user).toBeNull();
  });
});
