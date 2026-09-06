import type {TextStyle, ViewStyle} from 'react-native';

/**
 * Zabisa visual tokens.
 *
 * Nawasena is Zabisa's original enterprise visual language: confident cobalt,
 * deep navy, digital cyan and a restrained warm-gold accent. Feature screens
 * consume semantic tokens instead of another product's trade dress.
 */
export const colors = {
  primary: '#1769E0',
  primaryDark: '#0F4FB8',
  primaryDeep: '#082B69',
  primarySoft: '#DCEAFF',
  primarySofter: '#F0F6FF',
  sky: '#18A9E6',
  skySoft: '#DDF6FF',
  onPrimary: '#FFFFFF',
  onPrimaryMuted: '#DDEBFF',
  onPrimarySurface: 'rgba(255,255,255,0.15)',
  onPrimarySurfacePressed: 'rgba(255,255,255,0.22)',
  onPrimaryRipple: 'rgba(255,255,255,0.16)',
  accent: '#F4B942',
  accentDark: '#9A6710',
  accentSoft: '#FFF6DC',
  accentLine: '#F2D38C',
  background: '#F4F7FC',
  surface: '#FFFFFF',
  surfaceMuted: '#EEF3FA',
  surfaceWarm: '#FBFDFF',
  text: '#102A4C',
  textSoft: '#324A68',
  muted: '#687D99',
  line: '#DFE7F1',
  lineStrong: '#C7D4E5',
  success: '#197A5E',
  successSoft: '#E4F5EE',
  successLine: '#BBDDCB',
  warning: '#976A12',
  warningSoft: '#FFF5DD',
  danger: '#B7434F',
  dangerSoft: '#FFF0F1',
  dangerLine: '#E6C5C9',
  dangerIcon: '#F9DDE1',
  info: '#1769E0',
  white: '#FFFFFF',
  black: '#000000',
  scrim: 'rgba(8, 43, 105, 0.08)',
  ornament: 'rgba(244,185,66,0.38)',
  ornamentSoft: 'rgba(255,255,255,0.14)',
  ornamentStrong: 'rgba(255,255,255,0.55)',
} as const;

export const serviceColors = {
  donation: {solid: '#E84C86', soft: '#FDE8F0'},
  kajian: {solid: '#6557D9', soft: '#ECEAFF'},
  news: {solid: '#1677E8', soft: '#E4F1FF'},
  program: {solid: '#F08A24', soft: '#FFF0DF'},
  info: {solid: '#089A91', soft: '#DFF7F4'},
  gallery: {solid: '#8B4FD6', soft: '#F2E8FF'},
  notification: {solid: '#E96036', soft: '#FFE9E1'},
  account: {solid: '#087EBC', soft: '#E0F4FF'},
} as const;

export const space = {xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 32, xxxl: 40, jumbo: 56} as const;
export const radius = {sm: 10, md: 14, lg: 20, xl: 26, arch: 30, pill: 999} as const;
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
export const depth = {press: 4, serviceBase: 7, highlight: 2} as const;

export const shadow: ViewStyle = {
  shadowColor: '#0A3475',
  shadowOffset: {width: 0, height: 10},
  shadowOpacity: 0.16,
  shadowRadius: 24,
  elevation: 6,
};

export const shadowMedium: ViewStyle = {
  shadowColor: '#103B78',
  shadowOffset: {width: 0, height: 7},
  shadowOpacity: 0.11,
  shadowRadius: 18,
  elevation: 4,
};

export const shadowSoft: ViewStyle = {
  shadowColor: '#163E72',
  shadowOffset: {width: 0, height: 4},
  shadowOpacity: 0.07,
  shadowRadius: 14,
  elevation: 2,
};
