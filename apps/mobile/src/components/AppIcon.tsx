import React from 'react';
import {Image, StyleSheet, View} from 'react-native';
import {colors} from '../theme/tokens';

const sources = {
  home: require('../assets/icons/home.png'),
  kajian: require('../assets/icons/kajian.png'),
  donation: require('../assets/icons/donation.png'),
  notification: require('../assets/icons/notification.png'),
  account: require('../assets/icons/account.png'),
  news: require('../assets/icons/news.png'),
  program: require('../assets/icons/program.png'),
  info: require('../assets/icons/info.png'),
  gallery: require('../assets/icons/gallery.png'),
  attendance: require('../assets/icons/attendance.png'),
  grade: require('../assets/icons/grade.png'),
  tahfidz: require('../assets/icons/tahfidz.png'),
  chevronRight: require('../assets/icons/chevron-right.png'),
} as const;

export type AppIconName = keyof typeof sources;

type Props = {name: AppIconName; size?: number; color?: string; background?: boolean};

export function AppIcon({name, size = 22, color = colors.primary, background = false}: Props) {
  const image = <Image source={sources[name]} resizeMode="contain" style={{width: size, height: size, tintColor: color}} />;
  if (!background) return image;
  return <View style={styles.background}>{image}</View>;
}

const styles = StyleSheet.create({
  background: {width: 48, height: 48, borderRadius: 18, borderWidth: 1, borderColor: colors.lineStrong, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.primarySofter},
});
