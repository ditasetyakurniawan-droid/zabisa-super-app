import React from 'react';
import {Image, StatusBar, StyleSheet, Text, useWindowDimensions, View} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {AppIcon} from './AppIcon';
import {colors, radius, shadowSoft, space} from '../theme/tokens';

const HADITH = '“Sebaik-baik kalian adalah yang belajar Al-Qur’an dan mengajarkannya.”';

function BrandMark({compact}: {compact: boolean}) {
  return (
    <View style={[styles.brandMark, compact && styles.brandMarkCompact]}>
      <Text style={[styles.brandMarkText, compact && styles.brandMarkTextCompact]}>Z</Text>
      <View style={styles.brandDot} />
    </View>
  );
}

function QuoteCard({compact}: {compact: boolean}) {
  return (
    <View style={[styles.quoteCard, compact && styles.quoteCardCompact]}>
      <View style={styles.quoteEmblemRow}>
        <View style={styles.goldRule} />
        <View style={styles.quoteEmblem}>
          <AppIcon name="tahfidz" size={compact ? 20 : 23} color={colors.accent} />
        </View>
        <View style={styles.goldRule} />
      </View>
      <Text style={[styles.quote, compact && styles.quoteCompact]}>{HADITH}</Text>
      <Text style={[styles.source, compact && styles.sourceCompact]}>HR. Bukhari</Text>
    </View>
  );
}

function BackgroundLayer() {
  return (
    <View pointerEvents="none" style={StyleSheet.absoluteFill}>
      <Image
        accessibilityIgnoresInvertColors
        source={require('../assets/zabisa-premium-soft-bg.jpg')}
        resizeMode="cover"
        style={styles.backgroundImage}
      />
      <View style={styles.backgroundTint} />
      <View style={styles.backgroundVignetteTop} />
      <View style={styles.backgroundVignetteBottom} />
    </View>
  );
}

export function StartupLoading() {
  const {width, height} = useWindowDimensions();
  const compact = height < 840 || width < 380;
  const veryTall = height >= 900;
  const horizontalPadding = Math.max(space.lg, Math.min(space.xxl, width * 0.065));
  const heroWidth = Math.min(width * (compact ? 1.02 : 0.98), veryTall ? 420 : 400);
  const heroHeight = heroWidth * (840 / 841);

  return (
    <View style={styles.screen}>
      <StatusBar barStyle="light-content" />
      <BackgroundLayer />
      <SafeAreaView style={styles.safeArea} edges={['top', 'bottom']}>
        <View style={[styles.content, {paddingHorizontal: horizontalPadding}]}>
          <View style={[styles.brandBlock, compact && styles.brandBlockCompact]}>
            <BrandMark compact={compact} />
            <Text style={[styles.brand, compact && styles.brandCompact]}>Zabisa</Text>
            <Text style={[styles.tagline, compact && styles.taglineCompact]}>
              Belajar Al-Qur’an, tumbuh dalam adab.
            </Text>
          </View>

          <QuoteCard compact={compact} />

          <View style={[styles.heroStage, compact && styles.heroStageCompact]}>
            <Image
              accessibilityIgnoresInvertColors
              accessible={false}
              importantForAccessibility="no"
              source={require('../assets/zabisa-premium-hero-seamless.png')}
              resizeMode="contain"
              style={[styles.heroImage, {width: heroWidth, height: heroHeight}]}
            />
          </View>

          <View style={[styles.footerBlock, compact && styles.footerBlockCompact]}>
            <View style={[styles.footerRow, compact && styles.footerRowCompact]}>
              <View style={styles.footerRule} />
              <Text style={[styles.footnote, compact && styles.footnoteCompact]}>
                Pendidikan • Adab • Al-Qur’an
              </Text>
              <View style={styles.footerRule} />
            </View>
          </View>
        </View>
      </SafeAreaView>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: colors.primaryDeep,
    overflow: 'hidden',
  },
  safeArea: {flex: 1},
  content: {
    flex: 1,
    alignItems: 'center',
    paddingTop: space.sm,
    paddingBottom: space.sm,
  },
  backgroundImage: {
    position: 'absolute',
    top: 0,
    right: 0,
    bottom: 0,
    left: 0,
    width: undefined,
    height: undefined,
    opacity: 0.78,
  },
  backgroundTint: {
    position: 'absolute',
    top: 0,
    right: 0,
    bottom: 0,
    left: 0,
    backgroundColor: 'rgba(4,34,84,0.34)',
  },
  backgroundVignetteTop: {
    position: 'absolute',
    left: 0,
    right: 0,
    top: 0,
    height: '34%',
    backgroundColor: 'rgba(4,30,78,0.40)',
  },
  backgroundVignetteBottom: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 0,
    height: '26%',
    backgroundColor: 'rgba(2,19,50,0.52)',
  },
  brandBlock: {alignItems: 'center'},
  brandBlockCompact: {marginTop: -2},
  brandMark: {
    width: 60,
    height: 60,
    borderRadius: 21,
    backgroundColor: colors.primary,
    borderWidth: 1.5,
    borderColor: colors.accent,
    alignItems: 'center',
    justifyContent: 'center',
    ...shadowSoft,
  },
  brandMarkCompact: {width: 48, height: 48, borderRadius: 17},
  brandMarkText: {fontSize: 28, lineHeight: 32, fontWeight: '900', color: colors.white},
  brandMarkTextCompact: {fontSize: 23, lineHeight: 27},
  brandDot: {
    position: 'absolute',
    right: 7,
    top: 7,
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: colors.accent,
  },
  brand: {
    marginTop: 9,
    fontSize: 34,
    lineHeight: 39,
    fontWeight: '900',
    letterSpacing: -0.9,
    color: colors.white,
  },
  brandCompact: {marginTop: 5, fontSize: 29, lineHeight: 33},
  tagline: {
    marginTop: 2,
    maxWidth: 340,
    fontSize: 15,
    lineHeight: 22,
    fontWeight: '500',
    color: colors.onPrimaryMuted,
    textAlign: 'center',
  },
  taglineCompact: {fontSize: 13, lineHeight: 18},
  quoteCard: {
    width: '100%',
    maxWidth: 390,
    marginTop: 16,
    paddingHorizontal: 20,
    paddingTop: 15,
    paddingBottom: 14,
    borderRadius: radius.xl,
    borderWidth: 1,
    borderColor: 'rgba(174,215,255,0.68)',
    backgroundColor: 'rgba(255,255,255,0.085)',
    alignItems: 'center',
    shadowColor: '#53A8FF',
    shadowOffset: {width: 0, height: 5},
    shadowOpacity: 0.12,
    shadowRadius: 16,
    elevation: 2,
  },
  quoteCardCompact: {
    marginTop: 8,
    paddingHorizontal: 14,
    paddingTop: 10,
    paddingBottom: 9,
    borderRadius: radius.lg,
  },
  quoteEmblemRow: {flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 10},
  quoteEmblem: {
    width: 34,
    height: 28,
    alignItems: 'center',
    justifyContent: 'center',
  },
  goldRule: {width: 38, height: 1, backgroundColor: colors.accent, opacity: 0.86},
  quote: {
    marginTop: 7,
    maxWidth: 330,
    fontSize: 18,
    lineHeight: 24,
    fontWeight: '800',
    color: colors.white,
    textAlign: 'center',
    letterSpacing: -0.15,
  },
  quoteCompact: {marginTop: 4, fontSize: 15, lineHeight: 20, maxWidth: 285},
  source: {
    marginTop: 5,
    fontSize: 13,
    lineHeight: 18,
    fontWeight: '500',
    color: 'rgba(221,235,255,0.78)',
  },
  sourceCompact: {marginTop: 2, fontSize: 11, lineHeight: 15},
  heroStage: {
    width: '100%',
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: 6,
    marginBottom: 0,
  },
  heroStageCompact: {marginTop: 2},
  heroImage: {
    opacity: 1,
  },
  footerBlock: {
    width: '100%',
    maxWidth: 360,
    alignItems: 'center',
    marginTop: 20,
    paddingBottom: 2,
  },
  footerBlockCompact: {marginTop: 14},
  footerRow: {flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 10},
  footerRowCompact: {gap: 7},
  footerRule: {width: 28, height: 1, backgroundColor: colors.accent, opacity: 0.85},
  footnote: {
    fontSize: 10,
    lineHeight: 15,
    fontWeight: '600',
    color: 'rgba(221,235,255,0.82)',
    letterSpacing: 0.65,
  },
  footnoteCompact: {fontSize: 9, lineHeight: 13, letterSpacing: 0.45},
});
