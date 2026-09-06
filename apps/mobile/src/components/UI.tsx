import React from 'react';
import {
  AccessibilityInfo,
  ActivityIndicator,
  Animated,
  Easing,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  type TextInputProps,
  View,
  type ViewStyle,
} from 'react-native';
import {SafeAreaView, useSafeAreaInsets} from 'react-native-safe-area-context';
import {AppIcon, type AppIconName} from './AppIcon';
import {colors, control, motion, radius, shadow, shadowSoft, space, type} from '../theme/tokens';

function useAmbientMotion() {
  const value = React.useRef(new Animated.Value(0)).current;

  React.useEffect(() => {
    let active = true;
    let animation: Animated.CompositeAnimation | undefined;

    AccessibilityInfo.isReduceMotionEnabled().then(reduced => {
      if (!active || reduced) return;
      animation = Animated.loop(Animated.sequence([
        Animated.timing(value, {toValue: 1, duration: motion.ambient, easing: Easing.inOut(Easing.sin), useNativeDriver: true}),
        Animated.timing(value, {toValue: 0, duration: motion.ambient, easing: Easing.inOut(Easing.sin), useNativeDriver: true}),
      ]));
      animation.start();
    }).catch(() => undefined);

    return () => {
      active = false;
      animation?.stop();
    };
  }, [value]);

  return value;
}

export function IslamicOrnament({light = false, compact = false}: {light?: boolean; compact?: boolean}) {
  const motionValue = useAmbientMotion();
  const translateY = motionValue.interpolate({inputRange: [0, 1], outputRange: [0, compact ? -3 : -7]});
  const opacity = motionValue.interpolate({inputRange: [0, 1], outputRange: [0.58, 0.9]});

  return (
    <View accessibilityElementsHidden importantForAccessibility="no-hide-descendants" pointerEvents="none" style={[styles.ornament, compact && styles.ornamentCompact]}>
      <Animated.View style={[styles.ornamentHalo, compact && styles.ornamentHaloCompact, light && styles.ornamentHaloLight, {opacity, transform: [{translateY}]}]} />
      <Animated.View style={[styles.ornamentStar, compact && styles.ornamentStarCompact, light && styles.ornamentStarLight, {transform: [{translateY}, {rotate: '45deg'}]}]} />
      <View style={[styles.ornamentArch, compact && styles.ornamentArchCompact, light && styles.ornamentArchLight]} />
    </View>
  );
}

export function Screen({children, style, safeTop = true}: {children: React.ReactNode; style?: ViewStyle; safeTop?: boolean}) {
  return (
    <SafeAreaView edges={safeTop ? ['top'] : []} style={[styles.screen, style]}>
      <View pointerEvents="none" style={styles.canvasGlow} />
      <View style={styles.screenContent}>{children}</View>
    </SafeAreaView>
  );
}

export function ScrollScreen({children, contentStyle, safeTop = true}: {children: React.ReactNode; contentStyle?: ViewStyle; safeTop?: boolean}) {
  const insets = useSafeAreaInsets();
  return (
    <SafeAreaView edges={safeTop ? ['top'] : []} style={styles.screen}>
      <View pointerEvents="none" style={styles.canvasGlow} />
      <ScrollView
        style={styles.screen}
        contentContainerStyle={[styles.scrollContent, {paddingBottom: space.jumbo + insets.bottom}, contentStyle]}
        keyboardShouldPersistTaps="handled"
        showsVerticalScrollIndicator={false}>
        {children}
      </ScrollView>
    </SafeAreaView>
  );
}

export function AppHeader({eyebrow, title, subtitle}: {eyebrow?: string; title: string; subtitle?: string}) {
  return (
    <View style={styles.appHeader}>
      <View style={styles.headerCopy}>
        {eyebrow ? <View style={styles.eyebrowRow}><View style={styles.eyebrowLine} /><Text style={styles.eyebrow}>{eyebrow}</Text></View> : null}
        <Text accessibilityRole="header" style={styles.headerTitle}>{title}</Text>
        {subtitle ? <Text style={styles.headerSubtitle}>{subtitle}</Text> : null}
      </View>
      <IslamicOrnament compact />
    </View>
  );
}

export function Card({children, style, onPress}: {children: React.ReactNode; style?: ViewStyle; onPress?: () => void}) {
  if (onPress) {
    return <Pressable accessibilityRole="button" android_ripple={{color: colors.primarySoft}} onPress={onPress} style={({pressed}) => [styles.card, styles.pressableCard, style, pressed && styles.pressed]}>{children}</Pressable>;
  }
  return <View style={[styles.card, style]}>{children}</View>;
}

export function HeroCard({children}: {children: React.ReactNode}) {
  return (
    <View style={styles.hero}>
      <View pointerEvents="none" style={styles.heroGlow} />
      <IslamicOrnament light />
      <View style={styles.heroContent}>{children}</View>
    </View>
  );
}

export function Title({children}: {children: React.ReactNode}) {
  return <Text accessibilityRole="header" style={styles.title}>{children}</Text>;
}

export function DisplayTitle({children}: {children: React.ReactNode}) {
  return <Text accessibilityRole="header" style={styles.display}>{children}</Text>;
}

export function DetailHeader({eyebrow, title, subtitle, icon}: {eyebrow: string; title: string; subtitle?: string; icon: AppIconName}) {
  return (
    <View style={styles.detailHeader}>
      <IslamicOrnament compact />
      <View style={styles.detailHeaderRow}>
        <View style={styles.detailHeaderCopy}>
          <Text style={styles.detailEyebrow}>{eyebrow}</Text>
          <Text accessibilityRole="header" style={styles.detailTitle}>{title}</Text>
          {subtitle ? <Text style={styles.detailSubtitle}>{subtitle}</Text> : null}
        </View>
        <AppIcon name={icon} size={24} color={colors.primary} background />
      </View>
    </View>
  );
}

export function SectionTitle({children, action}: {children: React.ReactNode; action?: React.ReactNode}) {
  return <View style={styles.sectionRow}><Text accessibilityRole="header" style={styles.section}>{children}</Text>{action}</View>;
}

export function Muted({children, style}: {children: React.ReactNode; style?: object}) {
  return <Text style={[styles.muted, style]}>{children}</Text>;
}

export function Body({children, style}: {children: React.ReactNode; style?: object}) {
  return <Text style={[styles.body, style]}>{children}</Text>;
}

export function Button({title, onPress, disabled, secondary, icon, color = colors.primary, softColor = colors.primarySofter}: {title: string; onPress: () => void; disabled?: boolean; secondary?: boolean; icon?: AppIconName; color?: string; softColor?: string}) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{disabled: !!disabled}}
      accessibilityLabel={title}
      disabled={disabled}
      onPress={onPress}
      android_ripple={{color: secondary ? softColor : colors.onPrimaryRipple}}
      style={({pressed}) => [styles.button, {backgroundColor: color, borderColor: color}, secondary && styles.secondaryButton, secondary && {backgroundColor: softColor, borderColor: color}, disabled && styles.disabled, pressed && styles.pressed]}>
      {icon ? <AppIcon name={icon} size={19} color={secondary ? color : colors.white} /> : null}
      <Text style={[styles.buttonText, secondary && styles.secondaryButtonText, secondary && {color}]}>{title}</Text>
    </Pressable>
  );
}

export function TextButton({title, onPress}: {title: string; onPress: () => void}) {
  return <Pressable accessibilityRole="button" accessibilityLabel={title} onPress={onPress} hitSlop={8} style={({pressed}) => [styles.textButtonControl, pressed && styles.pressed]}><Text style={styles.textButton}>{title}</Text></Pressable>;
}

export function TextField({label, error, secureToggle, style, ...props}: TextInputProps & {label?: string; error?: string; secureToggle?: boolean}) {
  const [hidden, setHidden] = React.useState(!!props.secureTextEntry);
  const secure = secureToggle ? hidden : props.secureTextEntry;
  return (
    <View style={styles.fieldGroup}>
      {label ? <Text style={styles.fieldLabel}>{label}</Text> : null}
      <View style={[styles.inputShell, error && styles.inputError]}>
        <TextInput
          {...props}
          secureTextEntry={secure}
          placeholderTextColor={colors.muted}
          selectionColor={colors.primary}
          cursorColor={colors.primary}
          style={[styles.input, secureToggle && styles.inputWithAction, style]}
        />
        {secureToggle ? (
          <Pressable
            accessibilityRole="button"
            accessibilityLabel={hidden ? 'Tampilkan password' : 'Sembunyikan password'}
            hitSlop={8}
            onPress={() => setHidden(value => !value)}
            style={styles.inputAction}>
            <Text style={styles.inputActionText}>{hidden ? 'Lihat' : 'Sembunyikan'}</Text>
          </Pressable>
        ) : null}
      </View>
      {error ? <Text style={styles.fieldError}>{error}</Text> : null}
    </View>
  );
}

export function IconTile({icon, label, subtitle, onPress, color = colors.primary, softColor = colors.primarySofter}: {icon: AppIconName; label: string; subtitle?: string; onPress: () => void; color?: string; softColor?: string}) {
  return (
    <Pressable accessibilityRole="button" accessibilityLabel={label} onPress={onPress} android_ripple={{color: softColor}} style={({pressed}) => [styles.iconTile, pressed && styles.pressed]}>
      <View style={[styles.iconTileAccent, {backgroundColor: color}]} />
      <AppIcon name={icon} size={22} color={color} background backgroundColor={softColor} borderColor={softColor} />
      <View style={styles.iconTileCopy}>
        <Text numberOfLines={1} style={styles.iconTileText}>{label}</Text>
        {subtitle ? <Text numberOfLines={1} style={styles.iconTileSubtitle}>{subtitle}</Text> : null}
      </View>
      <Text style={[styles.iconTileArrow, {color}]}>›</Text>
    </Pressable>
  );
}

type PillTone = 'neutral' | 'success' | 'warning' | 'danger' | 'primary';

function pillToneStyle(tone: PillTone) {
  switch (tone) {
    case 'success': return styles.pillSuccess;
    case 'warning': return styles.pillWarning;
    case 'danger': return styles.pillDanger;
    case 'primary': return styles.pillPrimary;
    default: return styles.pillNeutral;
  }
}

function pillTextStyle(tone: PillTone) {
  switch (tone) {
    case 'success': return styles.pillTextSuccess;
    case 'warning': return styles.pillTextWarning;
    case 'danger': return styles.pillTextDanger;
    case 'primary': return styles.pillTextPrimary;
    default: return undefined;
  }
}

export function Pill({text, tone = 'neutral'}: {text: string; tone?: PillTone}) {
  const toneStyle = pillToneStyle(tone);
  const toneText = pillTextStyle(tone);
  return <View style={[styles.pill, toneStyle]}><Text style={[styles.pillText, toneText]}>{text}</Text></View>;
}

export function Loading({label = 'Memuat data...'}: {label?: string}) {
  return <View style={styles.state}><ActivityIndicator color={colors.primary} /><Muted style={{marginTop: space.sm}}>{label}</Muted></View>;
}

export function Empty({text = 'Belum ada data.', icon = 'info'}: {text?: string; icon?: AppIconName}) {
  return <View style={styles.state}><AppIcon name={icon} size={26} background /><Muted style={styles.stateText}>{text}</Muted></View>;
}

export function ErrorState({message = 'Data belum dapat dimuat.', onRetry}: {message?: string; onRetry?: () => void}) {
  return (
    <View style={styles.errorState}>
      <View style={styles.errorIcon}><Text style={styles.errorMark}>!</Text></View>
      <View style={styles.errorCopy}>
        <Text style={styles.errorTitle}>Belum tersambung</Text>
        <Muted>{message}</Muted>
      </View>
      {onRetry ? <Pressable accessibilityRole="button" accessibilityLabel="Coba lagi" onPress={onRetry} style={({pressed}) => [styles.errorRetry, pressed && styles.pressed]}><Text style={styles.errorRetryText}>Coba lagi</Text></Pressable> : null}
    </View>
  );
}

export function StatCard({icon, value, label}: {icon: AppIconName; value: string | number; label: string}) {
  return (
    <View style={styles.statCard}>
      <View style={styles.statIcon}><AppIcon name={icon} size={19} /></View>
      <Text style={styles.statValue}>{value}</Text>
      <Text style={styles.statLabel}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {flex: 1, backgroundColor: colors.background, overflow: 'hidden'},
  screenContent: {flex: 1, zIndex: 1},
  canvasGlow: {position: 'absolute', width: 300, height: 300, borderRadius: 150, backgroundColor: colors.skySoft, opacity: 0.62, right: -178, top: -142},
  scrollContent: {paddingHorizontal: space.lg, paddingTop: space.lg, paddingBottom: space.jumbo, zIndex: 1},
  appHeader: {paddingHorizontal: space.lg, paddingTop: space.xl, paddingBottom: space.lg, minHeight: 122, flexDirection: 'row', alignItems: 'flex-start', overflow: 'hidden'},
  headerCopy: {flex: 1, zIndex: 2, paddingRight: space.md},
  eyebrowRow: {flexDirection: 'row', alignItems: 'center', marginBottom: space.xs},
  eyebrowLine: {width: 22, height: 3, borderRadius: radius.pill, backgroundColor: colors.sky, marginRight: space.sm},
  eyebrow: {...type.micro, color: colors.primary, textTransform: 'uppercase'},
  headerTitle: {...type.title, color: colors.text},
  headerSubtitle: {...type.body, color: colors.muted, marginTop: space.xs, maxWidth: 520},
  card: {backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.line, borderRadius: radius.lg, padding: space.lg, marginBottom: space.md, ...shadowSoft},
  pressableCard: {overflow: 'hidden'},
  hero: {backgroundColor: colors.primaryDeep, borderRadius: radius.xl, minHeight: 238, overflow: 'hidden', position: 'relative', ...shadow},
  heroContent: {padding: space.xl, zIndex: 3},
  heroGlow: {position: 'absolute', width: 290, height: 290, borderRadius: 145, backgroundColor: colors.primary, opacity: 0.82, left: -130, bottom: -178},
  ornament: {position: 'absolute', width: 172, height: 172, right: -18, top: 8, alignItems: 'center', justifyContent: 'center', opacity: 0.92},
  ornamentCompact: {width: 92, height: 92, right: -8, top: 8, opacity: 0.7},
  ornamentHalo: {position: 'absolute', width: 116, height: 116, borderRadius: 58, borderWidth: 1, borderColor: colors.ornament},
  ornamentHaloCompact: {width: 60, height: 60, borderRadius: 30},
  ornamentHaloLight: {borderColor: colors.ornamentSoft},
  ornamentStar: {width: 38, height: 38, borderRadius: 8, borderWidth: 1.5, borderColor: colors.accent},
  ornamentStarCompact: {width: 22, height: 22, borderRadius: 5},
  ornamentStarLight: {borderColor: colors.ornamentStrong},
  ornamentArch: {position: 'absolute', bottom: 4, width: 82, height: 62, borderTopLeftRadius: 41, borderTopRightRadius: 41, borderWidth: 1, borderBottomWidth: 0, borderColor: colors.ornament},
  ornamentArchCompact: {width: 44, height: 32, borderTopLeftRadius: 22, borderTopRightRadius: 22, bottom: 2},
  ornamentArchLight: {borderColor: colors.ornamentSoft},
  title: {...type.title, color: colors.text},
  display: {...type.display, color: colors.text},
  detailHeader: {position: 'relative', overflow: 'hidden', backgroundColor: colors.surfaceWarm, borderWidth: 1, borderColor: colors.line, borderRadius: radius.xl, padding: space.xl, minHeight: 144, justifyContent: 'center', marginBottom: space.lg},
  detailHeaderRow: {flexDirection: 'row', alignItems: 'center', gap: space.lg, zIndex: 2},
  detailHeaderCopy: {flex: 1},
  detailEyebrow: {...type.micro, color: colors.accentDark, textTransform: 'uppercase', marginBottom: space.xs},
  detailTitle: {...type.title, color: colors.text},
  detailSubtitle: {...type.body, color: colors.muted, marginTop: space.xs},
  sectionRow: {flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginTop: space.xxl, marginBottom: space.md, gap: space.md},
  section: {...type.section, color: colors.text, flexShrink: 1},
  muted: {...type.body, color: colors.muted},
  body: {...type.body, color: colors.textSoft},
  button: {minHeight: control.buttonHeight, backgroundColor: colors.primary, borderRadius: radius.md, paddingVertical: 14, paddingHorizontal: 18, alignItems: 'center', justifyContent: 'center', flexDirection: 'row', gap: space.sm, marginTop: space.sm, borderWidth: 1, borderColor: colors.primary, ...shadowSoft},
  secondaryButton: {backgroundColor: colors.primarySofter, borderColor: colors.primary, shadowOpacity: 0},
  disabled: {opacity: 0.55},
  pressed: {opacity: 0.82, transform: [{scale: 0.985}]},
  buttonText: {...type.bodyStrong, color: colors.white},
  secondaryButtonText: {color: colors.primary},
  textButtonControl: {minHeight: control.minimumTapSize, minWidth: control.minimumTapSize, alignItems: 'center', justifyContent: 'center', paddingHorizontal: space.sm, marginVertical: -12},
  textButton: {...type.caption, color: colors.primary, fontWeight: '900'},
  fieldGroup: {marginBottom: space.lg},
  fieldLabel: {...type.caption, color: colors.textSoft, fontWeight: '800', marginBottom: space.sm},
  inputShell: {minHeight: control.fieldHeight, backgroundColor: colors.surfaceWarm, borderWidth: 1.2, borderColor: colors.lineStrong, borderRadius: radius.md, flexDirection: 'row', alignItems: 'center'},
  inputError: {borderColor: colors.danger},
  input: {...type.body, color: colors.text, flex: 1, minHeight: 56, paddingHorizontal: space.lg, paddingVertical: 12},
  inputWithAction: {paddingRight: 4},
  inputAction: {minWidth: 76, minHeight: 48, alignItems: 'center', justifyContent: 'center', paddingHorizontal: space.sm},
  inputActionText: {...type.caption, color: colors.primary, fontWeight: '900'},
  fieldError: {...type.caption, color: colors.danger, marginTop: space.sm},
  iconTile: {width: '48.5%', minHeight: 92, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.line, borderRadius: radius.lg, flexDirection: 'row', alignItems: 'center', padding: space.md, overflow: 'hidden', ...shadowSoft},
  iconTileAccent: {position: 'absolute', left: 0, top: 18, bottom: 18, width: 4, borderTopRightRadius: 4, borderBottomRightRadius: 4},
  iconTileCopy: {flex: 1, minWidth: 0, marginLeft: space.sm},
  iconTileText: {...type.caption, color: colors.text, fontWeight: '900'},
  iconTileSubtitle: {...type.micro, color: colors.muted, letterSpacing: 0, marginTop: 2},
  iconTileArrow: {fontSize: 21, fontWeight: '700', marginLeft: 2},
  pill: {alignSelf: 'flex-start', borderRadius: radius.pill, paddingHorizontal: 11, paddingVertical: 6},
  pillNeutral: {backgroundColor: colors.surfaceMuted},
  pillPrimary: {backgroundColor: colors.primarySoft},
  pillSuccess: {backgroundColor: colors.successSoft},
  pillWarning: {backgroundColor: colors.warningSoft},
  pillDanger: {backgroundColor: colors.dangerSoft},
  pillText: {...type.caption, color: colors.textSoft, fontWeight: '900'},
  pillTextPrimary: {color: colors.primary},
  pillTextSuccess: {color: colors.success},
  pillTextWarning: {color: colors.warning},
  pillTextDanger: {color: colors.danger},
  state: {paddingVertical: space.xxxl, paddingHorizontal: space.lg, alignItems: 'center', justifyContent: 'center'},
  stateText: {marginTop: space.md, textAlign: 'center', maxWidth: 300},
  errorState: {marginVertical: space.md, padding: space.md, borderWidth: 1, borderColor: colors.dangerLine, backgroundColor: colors.dangerSoft, borderRadius: radius.lg, flexDirection: 'row', alignItems: 'center'},
  errorIcon: {width: 40, height: 40, borderRadius: 14, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.dangerIcon, marginRight: space.md},
  errorCopy: {flex: 1, paddingRight: space.sm},
  errorMark: {fontSize: 20, fontWeight: '900', color: colors.danger},
  errorTitle: {...type.bodyStrong, color: colors.danger, marginBottom: space.xs},
  errorRetry: {minHeight: control.minimumTapSize, justifyContent: 'center', paddingHorizontal: space.sm},
  errorRetryText: {...type.caption, color: colors.danger, fontWeight: '900'},
  statCard: {flex: 1, minWidth: 0, minHeight: 136, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.line, borderRadius: radius.lg, padding: space.md, ...shadowSoft},
  statIcon: {width: 36, height: 36, borderRadius: 12, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.primarySoft},
  statValue: {fontSize: 27, lineHeight: 32, fontWeight: '900', color: colors.text, marginTop: space.md},
  statLabel: {...type.caption, color: colors.muted, marginTop: 2},
});
