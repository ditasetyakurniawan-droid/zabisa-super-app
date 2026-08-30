import type {TextStyle, ViewStyle} from 'react-native';

/**
 * Zabisa visual tokens.
 *
 * The palette intentionally uses a modern sky-blue financial-app direction
 * without copying another product's branding or trade dress. All screens must
 * consume these semantic tokens instead of hard-coded brand colours.
 */
export const colors = {
  primary: '#0878D1',
  primaryDark: '#075AA3',
  primaryDeep: '#06427B',
  primarySoft: '#E8F4FF',
  primarySofter: '#F3F9FF',
  sky: '#38A9F7',
  skySoft: '#DDF2FF',
  onPrimary: '#FFFFFF',
  onPrimaryMuted: '#D8F1FF',
  accent: '#FFB547',
  accentSoft: '#FFF5DE',
  accentLine: '#F0D79E',
  background: '#F4F9FE',
  surface: '#FFFFFF',
  surfaceMuted: '#EDF5FC',
  text: '#102A43',
  textSoft: '#334E68',
  muted: '#6B8297',
  line: '#D8E8F5',
  lineStrong: '#BDD6E9',
  success: '#159B72',
  successSoft: '#E8F8F2',
  warning: '#A76700',
  warningSoft: '#FFF4D9',
  danger: '#C43D4B',
  dangerSoft: '#FFF0F2',
  info: '#246BCE',
  white: '#FFFFFF',
  black: '#000000',
  scrim: 'rgba(9, 49, 82, 0.08)',
} as const;

export const space = {xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 32, xxxl: 40, jumbo: 48} as const;
export const radius = {sm: 10, md: 14, lg: 20, xl: 28, pill: 999} as const;
export const type = {
  display: {fontSize: 31, lineHeight: 38, fontWeight: '900' as TextStyle['fontWeight'], letterSpacing: -0.8},
  title: {fontSize: 24, lineHeight: 30, fontWeight: '900' as TextStyle['fontWeight'], letterSpacing: -0.4},
  section: {fontSize: 19, lineHeight: 25, fontWeight: '900' as TextStyle['fontWeight'], letterSpacing: -0.2},
  body: {fontSize: 15, lineHeight: 23, fontWeight: '400' as TextStyle['fontWeight']},
  bodyStrong: {fontSize: 15, lineHeight: 22, fontWeight: '800' as TextStyle['fontWeight']},
  caption: {fontSize: 12, lineHeight: 17, fontWeight: '600' as TextStyle['fontWeight']},
  micro: {fontSize: 10, lineHeight: 14, fontWeight: '800' as TextStyle['fontWeight'], letterSpacing: 0.5},
} as const;

export const shadow: ViewStyle = {
  shadowColor: colors.primaryDeep,
  shadowOffset: {width: 0, height: 6},
  shadowOpacity: 0.09,
  shadowRadius: 18,
  elevation: 3,
};

export const shadowSoft: ViewStyle = {
  shadowColor: colors.primaryDeep,
  shadowOffset: {width: 0, height: 2},
  shadowOpacity: 0.05,
  shadowRadius: 10,
  elevation: 1,
};
