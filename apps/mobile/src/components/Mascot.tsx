import React from 'react';
import {Image, StyleSheet, View, type ImageStyle, type StyleProp, type ViewStyle} from 'react-native';
import {AppIcon, type AppIconName} from './AppIcon';
import {colors, radius, serviceColors, shadowSoft} from '../theme/tokens';

export type MascotVariant =
  | 'welcome'
  | 'learning'
  | 'tahfidz'
  | 'academic'
  | 'attendance'
  | 'donation'
  | 'notification'
  | 'profile'
  | 'news'
  | 'program'
  | 'gallery'
  | 'about'
  | 'loading'
  | 'empty'
  | 'error';

type MascotSpec = {
  source: number;
  icon: AppIconName;
  color: string;
  soft: string;
  label: string;
};

const male = require('../assets/zabisa-quran-mascot.png');
const female = require('../assets/zabisa-female-mascot.png');
const premiumDuo = require('../assets/zabisa-premium-mascot-duo.png');

const specs: Record<MascotVariant, MascotSpec> = {
  welcome: {source: female, icon: 'home', color: colors.primary, soft: colors.primarySoft, label: 'Mascot santri putri menyambut'},
  learning: {source: male, icon: 'kajian', color: serviceColors.kajian.solid, soft: serviceColors.kajian.soft, label: 'Mascot santri belajar'},
  tahfidz: {source: male, icon: 'tahfidz', color: colors.primary, soft: colors.primarySoft, label: 'Mascot santri tahfidz'},
  academic: {source: female, icon: 'grade', color: serviceColors.program.solid, soft: serviceColors.program.soft, label: 'Mascot santri akademik'},
  attendance: {source: female, icon: 'attendance', color: serviceColors.info.solid, soft: serviceColors.info.soft, label: 'Mascot santri kehadiran'},
  donation: {source: female, icon: 'donation', color: serviceColors.donation.solid, soft: serviceColors.donation.soft, label: 'Mascot santri donasi'},
  notification: {source: female, icon: 'notification', color: serviceColors.notification.solid, soft: serviceColors.notification.soft, label: 'Mascot santri notifikasi'},
  profile: {source: male, icon: 'account', color: serviceColors.account.solid, soft: serviceColors.account.soft, label: 'Mascot santri profil'},
  news: {source: male, icon: 'news', color: serviceColors.news.solid, soft: serviceColors.news.soft, label: 'Mascot santri berita'},
  program: {source: female, icon: 'program', color: serviceColors.program.solid, soft: serviceColors.program.soft, label: 'Mascot santri program'},
  gallery: {source: female, icon: 'gallery', color: serviceColors.gallery.solid, soft: serviceColors.gallery.soft, label: 'Mascot santri galeri'},
  about: {source: male, icon: 'info', color: serviceColors.info.solid, soft: serviceColors.info.soft, label: 'Mascot santri informasi'},
  loading: {source: male, icon: 'info', color: colors.primary, soft: colors.primarySoft, label: 'Mascot santri sedang memuat'},
  empty: {source: female, icon: 'info', color: colors.sky, soft: colors.skySoft, label: 'Mascot santri untuk keadaan kosong'},
  error: {source: male, icon: 'info', color: colors.danger, soft: colors.dangerSoft, label: 'Mascot santri untuk keadaan error'},
};

export function Mascot({variant = 'learning', size = 84, decorative = false, imageStyle, style, unframed = false}: {variant?: MascotVariant; size?: number; decorative?: boolean; imageStyle?: StyleProp<ImageStyle>; style?: StyleProp<ViewStyle>; unframed?: boolean}) {
  const spec = specs[variant];
  const accessibilityProps = {
    accessible: !decorative,
    accessibilityLabel: decorative ? undefined : spec.label,
    accessibilityRole: decorative ? undefined : ('image' as const),
    importantForAccessibility: decorative ? ('no' as const) : ('auto' as const),
  };

  if (unframed) {
    return (
      <View {...accessibilityProps} style={[styles.unframed, {width: size, height: size * 1.48}, style]}>
        <Image accessibilityIgnoresInvertColors source={spec.source} resizeMode="contain" style={[styles.unframedImage, {width: size, height: size * 1.48}, imageStyle]} />
      </View>
    );
  }

  return (
    <View {...accessibilityProps} style={[styles.shell, {width: size, height: size, borderColor: spec.soft, backgroundColor: spec.soft}, style]}>
      <Image accessibilityIgnoresInvertColors source={spec.source} resizeMode="contain" style={[styles.image, {width: size * 0.86, height: size * 0.96}, imageStyle]} />
      <View style={[styles.badge, {backgroundColor: spec.color}]}>
        <AppIcon name={spec.icon} size={Math.max(13, Math.round(size * 0.18))} color={colors.white} />
      </View>
    </View>
  );
}

export function MascotDuo({width = 266, decorative = true, style}: {width?: number; decorative?: boolean; style?: StyleProp<ViewStyle>}) {
  const height = width * (821 / 646);
  return (
    <View
      accessible={!decorative}
      accessibilityLabel={decorative ? undefined : 'Mascot santri putra dan putri Zabisa'}
      accessibilityRole={decorative ? undefined : 'image'}
      importantForAccessibility={decorative ? 'no' : 'auto'}
      style={[styles.duo, {width, height}, style]}>
      <Image
        accessibilityIgnoresInvertColors
        source={premiumDuo}
        resizeMode="contain"
        style={{width, height}}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  shell: {borderRadius: radius.xl, borderWidth: 1, alignItems: 'center', justifyContent: 'flex-end', overflow: 'hidden', ...shadowSoft},
  unframed: {alignItems: 'center', justifyContent: 'flex-end'},
  unframedImage: {position: 'absolute', bottom: 0},
  image: {marginBottom: -4},
  duo: {alignItems: 'center', justifyContent: 'center'},
  badge: {position: 'absolute', right: 5, bottom: 5, minWidth: 28, minHeight: 28, borderRadius: radius.pill, alignItems: 'center', justifyContent: 'center', borderWidth: 2, borderColor: colors.white},
});
