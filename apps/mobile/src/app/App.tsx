import React from 'react';
import {ActivityIndicator, StatusBar, View} from 'react-native';
import {GestureHandlerRootView} from 'react-native-gesture-handler';
import {QueryClient, QueryClientProvider} from '@tanstack/react-query';
import {SafeAreaProvider} from 'react-native-safe-area-context';
import RootNavigator from '../navigation/RootNavigator';
import {useAuth} from '../store/auth';
import {colors} from '../theme/tokens';

const queryClient = new QueryClient({defaultOptions: {queries: {staleTime: 30_000, retry: 1, refetchOnWindowFocus: false}, mutations: {retry: 0}}});

function Bootstrap() {
  const hydrated = useAuth(state => state.hydrated);
  const hydrate = useAuth(state => state.hydrate);
  React.useEffect(() => { hydrate(); }, [hydrate]);
  if (!hydrated) return <View style={{flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.background}}><ActivityIndicator color={colors.primary} /></View>;
  return <RootNavigator />;
}

export default function App() {
  return <GestureHandlerRootView style={{flex: 1}}><SafeAreaProvider><StatusBar barStyle="dark-content" /><QueryClientProvider client={queryClient}><Bootstrap /></QueryClientProvider></SafeAreaProvider></GestureHandlerRootView>;
}
