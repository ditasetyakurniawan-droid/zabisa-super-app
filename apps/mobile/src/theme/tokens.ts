import type {TextStyle, ViewStyle} from 'react-native';

/**
 * Zabisa visual tokens.
 *
 * The Sakinah palette combines emerald, warm ivory and restrained gold. It is
 * an original Zabisa visual language inspired by calm Islamic geometry without
 * copying another product's branding or trade dress. Feature screens consume
 * semantic tokens instead of hard-coded brand colours.
 */
export const colors = {
  primary: '#087A68',
  primaryDark: '#075F54',
  primaryDeep: '#063F3A',
  primarySoft: '#DDF3ED',
  primarySofter: '#F1FAF7',
  sky: '#25A58D',
  skySoft: '#D7F3EC',
  onPrimary: '#FFFFFF',
  onPrimaryMuted: '#D7F3EC',
  onPrimarySurface: 'rgba(255,255,255,0.15)',
  onPrimarySurfacePressed: 'rgba(255,255,255,0.22)',
  onPrimaryRipple: 'rgba(255,255,255,0.16)',
  accent: '#D6A94F',
  accentDark: '#946D21',
  accentSoft: '#FFF7E7',
  accentLine: '#E9D39E',
  background: '#F7F8F3',
  surface: '#FFFFFF',
  surfaceMuted: '#F0F3EC',
  surfaceWarm: '#FFFDF8',
  text: '#17332F',
  textSoft: '#3C5853',
  muted: '#687D78',
  line: '#DCE7E1',
  lineStrong: '#BDD5CC',
  success: '#197A5E',
  successSoft: '#E4F5EE',
  successLine: '#BBDDCB',
  warning: '#976A12',
  warningSoft: '#FFF5DD',
  danger: '#B7434F',
  dangerSoft: '#FFF0F1',
  dangerLine: '#E6C5C9',
  dangerIcon: '#F9DDE1',
  info: '#276D76',
  white: '#FFFFFF',
  black: '#000000',
  scrim: 'rgba(6, 63, 58, 0.08)',
  ornament: 'rgba(214,169,79,0.34)',
  ornamentSoft: 'rgba(255,255,255,0.14)',
  ornamentStrong: 'rgba(255,255,255,0.55)',
} as const;

export const space = {xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 32, xxxl: 40, jumbo: 56} as const;
export const radius = {sm: 10, md: 16, lg: 22, xl: 30, arch: 42, pill: 999} as const;
export const type = {
  display: {fontSize: 32, lineHeight: 40, fontWeight: '900' as TextStyle['fontWeight'], letterSpacing: -0.8},
  title: {fontSize: 25, lineHeight: 32, fontWeight: '900' as TextStyle['fontWeight'], letterSpacing: -0.45},
  section: {fontSize: 19, lineHeight: 26, fontWeight: '900' as TextStyle['fontWeight'], letterSpacing: -0.15},
  body: {fontSize: 15, lineHeight: 24, fontWeight: '400' as TextStyle['fontWeight']},
  bodyStrong: {fontSize: 15, lineHeight: 23, fontWeight: '800' as TextStyle['fontWeight']},
  caption: {fontSize: 12, lineHeight: 18, fontWeight: '600' as TextStyle['fontWeight']},
  micro: {fontSize: 10, lineHeight: 15, fontWeight: '800' as TextStyle['fontWeight'], letterSpacing: 0.8},
} as const;

export const motion = {quick: 160, standard: 280, ambient: 4200} as const;
export const control = {minimumTapSize: 48, buttonHeight: 54, fieldHeight: 58} as const;

export const shadow: ViewStyle = {
  shadowColor: colors.primaryDeep,
  shadowOffset: {width: 0, height: 6},
  shadowOpacity: 0.11,
  shadowRadius: 20,
  elevation: 4,
};

export const shadowSoft: ViewStyle = {
  shadowColor: colors.primaryDeep,
  shadowOffset: {width: 0, height: 2},
  shadowOpacity: 0.05,
  shadowRadius: 10,
  elevation: 1,
};
