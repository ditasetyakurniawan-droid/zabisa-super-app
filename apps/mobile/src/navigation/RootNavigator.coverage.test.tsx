import React from 'react';
import {afterEach, beforeEach, describe, expect, it, jest} from '@jest/globals';
import {act, create} from 'react-test-renderer';
import {Linking} from 'react-native';
import type {User} from '../types/domain';

let mockUser: User | null = null;
const mockNavigate = jest.fn();
const mockNavigationRef = {
  isReady: jest.fn(() => true),
  navigate: mockNavigate,
};

jest.mock('@react-navigation/native', () => {
  const ReactModule = require('react');
  return {
    createNavigationContainerRef: () => mockNavigationRef,
    DefaultTheme: {colors: {primary: '#000', background: '#fff', card: '#fff', text: '#000', border: '#ddd', notification: '#f00'}},
    NavigationContainer: ({children, onReady}: {children: React.ReactNode; onReady?: () => void}) => {
      ReactModule.useEffect(() => { onReady?.(); }, [onReady]);
      return children;
    },
  };
});

jest.mock('@react-navigation/bottom-tabs', () => {
  return {
    createBottomTabNavigator: () => ({
      Navigator: ({children}: {children: React.ReactNode}) => children,
      Screen: ({name, options, listeners}: {
        name: string;
        options?: {tabBarIcon?: (props: {color: string; size: number; focused: boolean}) => React.ReactNode};
        listeners?: (props: {navigation: {getParent: () => {navigate: typeof mockNavigate}}}) => {tabPress: (event: {preventDefault: () => void}) => void};
      }) => {
        options?.tabBarIcon?.({color: '#64748b', size: 24, focused: name === 'Home'});
        if (name === 'Akun' && listeners) {
          listeners({navigation: {getParent: () => ({navigate: mockNavigate})}})
            .tabPress({preventDefault: jest.fn()});
        }
        return null;
      },
    }),
  };
});

jest.mock('@react-navigation/native-stack', () => {
  const ReactModule = require('react');
  return {
    createNativeStackNavigator: () => ({
      Navigator: ({children}: {children: React.ReactNode}) => children,
      Screen: ({name, component}: {name: string; component: React.ComponentType}) =>
        name === 'Main' ? ReactModule.createElement(component) : null,
    }),
  };
});

jest.mock('../store/auth', () => ({
  useAuth: (selector: (state: {user: User | null}) => unknown) => selector({user: mockUser}),
}));

jest.mock('../api/client', () => ({api: jest.fn()}));

jest.mock('../features/home/HomeScreen', () => () => null);
jest.mock('../features/kajian/KajianScreen', () => () => null);
jest.mock('../features/kajian/KajianDetailScreen', () => () => null);
jest.mock('../features/donation/DonationScreen', () => () => null);
jest.mock('../features/donation/CampaignDetailScreen', () => () => null);
jest.mock('../features/donation/DonationCheckoutScreen', () => () => null);
jest.mock('../features/notifications/NotificationsScreen', () => () => null);
jest.mock('../features/account/AccountScreen', () => () => null);
jest.mock('../features/auth/LoginScreen', () => () => null);
jest.mock('../features/guardian/GuardianOverviewScreen', () => () => null);
jest.mock('../features/guardian/GuardianStudentScreen', () => () => null);
jest.mock('../features/content/ContentListScreen', () => () => null);
jest.mock('../features/content/ContentDetailScreen', () => () => null);

const RootNavigator = require('./RootNavigator').default as React.ComponentType;

describe('Nawasena root navigation presentation', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockUser = null;
    jest.spyOn(Linking, 'getInitialURL').mockResolvedValue(null);
    jest.spyOn(Linking, 'addEventListener').mockReturnValue({remove: jest.fn()} as never);
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('renders all coloured tab icons and protects the account tab for guests', async () => {
    jest.mocked(Linking.getInitialURL).mockResolvedValue('zabisa://unknown');
    await act(async () => {
      create(<RootNavigator />);
      await Promise.resolve();
    });

    expect(mockNavigate).toHaveBeenCalledWith('Login');
    expect(mockNavigationRef.isReady).toHaveBeenCalled();
  });

  it('allows an authenticated user to render the account tab without redirect', async () => {
    mockUser = {id: 'guardian-1', email: 'wali@example.test', name: 'Wali Demo', role: 'GUARDIAN', status: 'ACTIVE'};
    await act(async () => {
      create(<RootNavigator />);
      await Promise.resolve();
    });

    expect(mockNavigate).not.toHaveBeenCalledWith('Login');
  });
});
