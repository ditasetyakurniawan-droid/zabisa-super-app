import React from 'react';
import {Linking} from 'react-native';
import {
  createNavigationContainerRef,
  DefaultTheme,
  NavigationContainer,
} from '@react-navigation/native';
import {createBottomTabNavigator, type BottomTabNavigationOptions} from '@react-navigation/bottom-tabs';
import {createNativeStackNavigator} from '@react-navigation/native-stack';
import HomeScreen from '../features/home/HomeScreen';
import KajianScreen from '../features/kajian/KajianScreen';
import KajianDetailScreen from '../features/kajian/KajianDetailScreen';
import DonationScreen from '../features/donation/DonationScreen';
import CampaignDetailScreen from '../features/donation/CampaignDetailScreen';
import DonationCheckoutScreen from '../features/donation/DonationCheckoutScreen';
import NotificationsScreen from '../features/notifications/NotificationsScreen';
import AccountScreen from '../features/account/AccountScreen';
import LoginScreen from '../features/auth/LoginScreen';
import GuardianOverviewScreen from '../features/guardian/GuardianOverviewScreen';
import GuardianStudentScreen from '../features/guardian/GuardianStudentScreen';
import ContentListScreen from '../features/content/ContentListScreen';
import ContentDetailScreen from '../features/content/ContentDetailScreen';
import {AppIcon, type AppIconName} from '../components/AppIcon';
import {colors} from '../theme/tokens';
import {useAuth} from '../store/auth';
import {api} from '../api/client';
import type {Kajian, Student} from '../types/domain';
import {parseZabisaDeepLink} from '../features/notifications/deepLink';
import type {MainTabParamList, RootStackParamList} from './types';

const Tab = createBottomTabNavigator<MainTabParamList>();
const Stack = createNativeStackNavigator<RootStackParamList>();
const navigationRef = createNavigationContainerRef<RootStackParamList>();
type IconProps = {color: string; size: number};
const makeIcon = (name: AppIconName) => function TabIcon({color, size}: IconProps) {
  return <AppIcon name={name} color={color} size={Math.min(size, 22)} />;
};
const iconRenderers = {
  Home: makeIcon('home'),
  Kajian: makeIcon('kajian'),
  Donasi: makeIcon('donation'),
  Notifikasi: makeIcon('notification'),
  Akun: makeIcon('account'),
};

const tabBaseOptions: BottomTabNavigationOptions = {
  headerShown: false,
  tabBarActiveTintColor: colors.primary,
  tabBarInactiveTintColor: colors.muted,
  tabBarActiveBackgroundColor: colors.primarySofter,
  tabBarHideOnKeyboard: true,
  tabBarStyle: {
    height: 66,
    paddingBottom: 6,
    paddingTop: 6,
    borderTopColor: colors.line,
    borderTopWidth: 1,
    backgroundColor: colors.surface,
  },
  tabBarLabelStyle: {fontSize: 10.5, fontWeight: '800'},
  tabBarItemStyle: {borderRadius: 15, marginHorizontal: 3, marginVertical: 4},
};

function Tabs() {
  const user = useAuth(s => s.user);
  return (
    <Tab.Navigator screenOptions={tabBaseOptions}>
      <Tab.Screen name="Home" component={HomeScreen} options={{title: 'Beranda', tabBarIcon: iconRenderers.Home}} />
      <Tab.Screen name="Kajian" component={KajianScreen} options={{tabBarIcon: iconRenderers.Kajian}} />
      <Tab.Screen name="Donasi" component={DonationScreen} options={{tabBarIcon: iconRenderers.Donasi}} />
      <Tab.Screen name="Notifikasi" component={NotificationsScreen} options={{tabBarIcon: iconRenderers.Notifikasi}} />
      <Tab.Screen
        name="Akun"
        component={AccountScreen}
        options={{tabBarIcon: iconRenderers.Akun}}
        listeners={({navigation}) => ({
          tabPress: event => {
            if (!user) {
              event.preventDefault();
              (navigation.getParent() as any)?.navigate('Login');
            }
          },
        })}
      />
    </Tab.Navigator>
  );
}

export default function RootNavigator() {
  const user = useAuth(s => s.user);
  const pendingUrl = React.useRef<string | null>(null);
  const initialUrlRead = React.useRef(false);

  const openDeepLink = React.useCallback(async (url: string) => {
    if (!navigationRef.isReady()) {
      pendingUrl.current = url;
      return;
    }
    const parsed = parseZabisaDeepLink(url);
    if (parsed.kind === 'kajian') {
      try {
        const items = await api<Kajian[]>('/api/v1/kajian');
        const item = items.find(value => value.id === parsed.kajianId);
        if (item) navigationRef.navigate('KajianDetail', {kajian: item});
        else navigationRef.navigate('Main', {screen: 'Kajian'});
      } catch {
        navigationRef.navigate('Main', {screen: 'Kajian'});
      }
      return;
    }

    if (parsed.kind === 'guardian' || parsed.kind === 'legacy-guardian') {
      const guardian = !!user && ['GUARDIAN', 'WALI_SANTRI'].includes(user.role);
      if (!guardian) {
        pendingUrl.current = url;
        navigationRef.navigate('Login');
        return;
      }
      try {
        const students = await api<Student[]>('/api/v1/guardian/students');
        const student = parsed.kind === 'guardian'
          ? students.find(value => value.id === parsed.studentId)
          : students.length === 1 ? students[0] : undefined;
        if (student) navigationRef.navigate('GuardianStudent', {student});
        else navigationRef.navigate('GuardianOverview');
      } catch {
        navigationRef.navigate('GuardianOverview');
      }
    }
  }, [user]);

  React.useEffect(() => {
    if (!initialUrlRead.current) {
      initialUrlRead.current = true;
      Linking.getInitialURL().then(url => {
        if (url) openDeepLink(url);
      }).catch(() => undefined);
    }
    const subscription = Linking.addEventListener('url', event => openDeepLink(event.url));
    return () => subscription.remove();
  }, [openDeepLink]);

  React.useEffect(() => {
    if (user && pendingUrl.current && navigationRef.isReady()) {
      const url = pendingUrl.current;
      pendingUrl.current = null;
      openDeepLink(url);
    }
  }, [openDeepLink, user]);

  return (
    <NavigationContainer
      ref={navigationRef}
      onReady={() => {
        if (pendingUrl.current) {
          const url = pendingUrl.current;
          pendingUrl.current = null;
          openDeepLink(url);
        }
      }}
      theme={{...DefaultTheme, colors: {...DefaultTheme.colors, primary: colors.primary, background: colors.background, card: colors.surface, text: colors.text, border: colors.line, notification: colors.danger}}}>
      <Stack.Navigator screenOptions={{headerTintColor: colors.text, headerStyle: {backgroundColor: colors.surface}, headerTitleStyle: {fontWeight: '800'}, headerShadowVisible: false, contentStyle: {backgroundColor: colors.background}}}>
        <Stack.Screen name="Main" component={Tabs} options={{headerShown: false}} />
        <Stack.Screen name="Login" component={LoginScreen} options={{title: 'Masuk ke Zabisa'}} />
        <Stack.Screen name="KajianDetail" component={KajianDetailScreen} options={{title: 'Detail Kajian'}} />
        <Stack.Screen name="CampaignDetail" component={CampaignDetailScreen} options={{title: 'Detail Campaign'}} />
        <Stack.Screen name="DonationCheckout" component={DonationCheckoutScreen} options={{title: 'Donasi'}} />
        <Stack.Screen name="GuardianOverview" component={GuardianOverviewScreen} options={{title: 'Data Ananda'}} />
        <Stack.Screen name="GuardianStudent" component={GuardianStudentScreen} options={{title: 'Perkembangan Santri'}} />
        <Stack.Screen name="ContentList" component={ContentListScreen} options={({route}) => ({title: route.params?.title || 'Informasi'})} />
        <Stack.Screen name="ContentDetail" component={ContentDetailScreen} options={({route}) => ({title: route.params?.title || 'Detail'})} />
      </Stack.Navigator>
    </NavigationContainer>
  );
}
