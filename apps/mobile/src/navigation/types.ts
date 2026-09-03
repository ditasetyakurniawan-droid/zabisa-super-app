import type {CompositeScreenProps, NavigatorScreenParams} from '@react-navigation/native';
import type {BottomTabScreenProps} from '@react-navigation/bottom-tabs';
import type {NativeStackScreenProps} from '@react-navigation/native-stack';
import type {Campaign, Kajian, Student} from '../types/domain';

export type MainTabParamList = {
  Home: undefined;
  Kajian: undefined;
  Donasi: undefined;
  Notifikasi: undefined;
  Akun: undefined;
};

export type RootStackParamList = {
  Main: NavigatorScreenParams<MainTabParamList> | undefined;
  Login: undefined;
  KajianDetail: {kajian: Kajian};
  CampaignDetail: {campaign: Campaign};
  DonationCheckout: {campaign: Campaign};
  GuardianOverview: undefined;
  GuardianStudent: {student: Student};
  ContentList: {type: string; title: string};
  ContentDetail: {id: string; title: string};
};

export type RootStackScreenProps<RouteName extends keyof RootStackParamList> =
  NativeStackScreenProps<RootStackParamList, RouteName>;

export type MainTabScreenProps<RouteName extends keyof MainTabParamList> =
  CompositeScreenProps<
    BottomTabScreenProps<MainTabParamList, RouteName>,
    NativeStackScreenProps<RootStackParamList>
  >;
