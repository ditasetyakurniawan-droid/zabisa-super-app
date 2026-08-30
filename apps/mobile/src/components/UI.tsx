import React from 'react';
import {
  ActivityIndicator,
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
import {colors, radius, shadow, shadowSoft, space, type} from '../theme/tokens';

export function Screen({children, style, safeTop = true}: {children: React.ReactNode; style?: ViewStyle; safeTop?: boolean}) {
  return <SafeAreaView edges={safeTop ? ['top'] : []} style={[styles.screen, style]}>{children}</SafeAreaView>;
}

export function ScrollScreen({children, contentStyle, safeTop = true}: {children: React.ReactNode; contentStyle?: ViewStyle; safeTop?: boolean}) {
  const insets = useSafeAreaInsets();
  return (
    <SafeAreaView edges={safeTop ? ['top'] : []} style={styles.screen}>
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
      {eyebrow ? <Text style={styles.eyebrow}>{eyebrow}</Text> : null}
      <Text accessibilityRole="header" style={styles.headerTitle}>{title}</Text>
      {subtitle ? <Text style={styles.headerSubtitle}>{subtitle}</Text> : null}
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
      <View pointerEvents="none" style={styles.heroBubbleLarge} />
      <View pointerEvents="none" style={styles.heroBubbleSmall} />
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

export function SectionTitle({children, action}: {children: React.ReactNode; action?: React.ReactNode}) {
  return <View style={styles.sectionRow}><Text accessibilityRole="header" style={styles.section}>{children}</Text>{action}</View>;
}

export function Muted({children, style}: {children: React.ReactNode; style?: object}) {
  return <Text style={[styles.muted, style]}>{children}</Text>;
}

export function Body({children, style}: {children: React.ReactNode; style?: object}) {
  return <Text style={[styles.body, style]}>{children}</Text>;
}

export function Button({title, onPress, disabled, secondary, icon}: {title: string; onPress: () => void; disabled?: boolean; secondary?: boolean; icon?: AppIconName}) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{disabled: !!disabled}}
      disabled={disabled}
      onPress={onPress}
      android_ripple={{color: secondary ? colors.skySoft : 'rgba(255,255,255,0.16)'}}
      style={({pressed}) => [styles.button, secondary && styles.secondaryButton, disabled && styles.disabled, pressed && styles.pressed]}>
      {icon ? <AppIcon name={icon} size={19} color={secondary ? colors.primary : colors.white} /> : null}
      <Text style={[styles.buttonText, secondary && styles.secondaryButtonText]}>{title}</Text>
    </Pressable>
  );
}

export function TextButton({title, onPress}: {title: string; onPress: () => void}) {
  return <Pressable accessibilityRole="button" onPress={onPress} hitSlop={10}><Text style={styles.textButton}>{title}</Text></Pressable>;
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

export function IconTile({icon, label, onPress}: {icon: AppIconName; label: string; onPress: () => void}) {
  return (
    <Pressable accessibilityRole="button" accessibilityLabel={label} onPress={onPress} android_ripple={{color: colors.primarySoft}} style={({pressed}) => [styles.iconTile, pressed && styles.pressed]}>
      <AppIcon name={icon} size={23} background />
      <Text numberOfLines={1} style={styles.iconTileText}>{label}</Text>
    </Pressable>
  );
}

export function Pill({text, tone = 'neutral'}: {text: string; tone?: 'neutral' | 'success' | 'warning' | 'danger' | 'primary'}) {
  const toneStyle = tone === 'success' ? styles.pillSuccess : tone === 'warning' ? styles.pillWarning : tone === 'danger' ? styles.pillDanger : tone === 'primary' ? styles.pillPrimary : styles.pillNeutral;
  const toneText = tone === 'primary' ? styles.pillTextPrimary : tone === 'success' ? styles.pillTextSuccess : tone === 'warning' ? styles.pillTextWarning : tone === 'danger' ? styles.pillTextDanger : undefined;
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
      <Text style={styles.errorTitle}>Ada kendala</Text>
      <Muted style={{textAlign: 'center'}}>{message}</Muted>
      {onRetry ? <Button secondary title="Coba lagi" onPress={onRetry} /> : null}
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
  screen: {flex: 1, backgroundColor: colors.background},
  scrollContent: {paddingHorizontal: space.lg, paddingTop: space.lg, paddingBottom: space.jumbo},
  appHeader: {paddingHorizontal: space.lg, paddingTop: space.lg, paddingBottom: space.md},
  eyebrow: {...type.micro, color: colors.primary, textTransform: 'uppercase', marginBottom: 4},
  headerTitle: {...type.title, color: colors.text},
  headerSubtitle: {...type.body, color: colors.muted, marginTop: 4},
  card: {backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.line, borderRadius: radius.lg, padding: space.lg, marginBottom: space.md, ...shadowSoft},
  pressableCard: {overflow: 'hidden'},
  hero: {backgroundColor: colors.primary, borderRadius: radius.xl, minHeight: 198, overflow: 'hidden', position: 'relative', ...shadow},
  heroContent: {padding: space.xl, zIndex: 2},
  heroBubbleLarge: {position: 'absolute', width: 210, height: 210, borderRadius: 105, backgroundColor: 'rgba(255,255,255,0.10)', right: -82, top: -72},
  heroBubbleSmall: {position: 'absolute', width: 92, height: 92, borderRadius: 46, backgroundColor: 'rgba(255,255,255,0.09)', right: 78, bottom: -38},
  title: {...type.title, color: colors.text},
  display: {...type.display, color: colors.text},
  sectionRow: {flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginTop: space.xxl, marginBottom: space.md},
  section: {...type.section, color: colors.text, flexShrink: 1},
  muted: {...type.body, color: colors.muted},
  body: {...type.body, color: colors.textSoft},
  button: {minHeight: 52, backgroundColor: colors.primary, borderRadius: radius.md, paddingVertical: 14, paddingHorizontal: 18, alignItems: 'center', justifyContent: 'center', flexDirection: 'row', gap: space.sm, marginTop: space.sm, ...shadowSoft},
  secondaryButton: {backgroundColor: colors.primarySoft, borderWidth: 1, borderColor: colors.lineStrong, shadowOpacity: 0},
  disabled: {opacity: 0.55},
  pressed: {opacity: 0.78, transform: [{scale: 0.99}]},
  buttonText: {...type.bodyStrong, color: colors.white},
  secondaryButtonText: {color: colors.primary},
  textButton: {...type.caption, color: colors.primary, fontWeight: '900'},
  fieldGroup: {marginBottom: space.lg},
  fieldLabel: {...type.caption, color: colors.textSoft, fontWeight: '800', marginBottom: space.sm},
  inputShell: {minHeight: 58, backgroundColor: colors.surface, borderWidth: 1.2, borderColor: colors.lineStrong, borderRadius: radius.md, flexDirection: 'row', alignItems: 'center'},
  inputError: {borderColor: colors.danger},
  input: {...type.body, color: colors.text, flex: 1, minHeight: 56, paddingHorizontal: space.lg, paddingVertical: 12},
  inputWithAction: {paddingRight: 4},
  inputAction: {minWidth: 76, minHeight: 48, alignItems: 'center', justifyContent: 'center', paddingHorizontal: space.sm},
  inputActionText: {...type.caption, color: colors.primary, fontWeight: '900'},
  fieldError: {...type.caption, color: colors.danger, marginTop: space.sm},
  iconTile: {width: '23.5%', minHeight: 104, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.line, borderRadius: radius.lg, alignItems: 'center', justifyContent: 'center', paddingHorizontal: space.xs, paddingVertical: space.md, ...shadowSoft},
  iconTileText: {...type.caption, color: colors.text, fontWeight: '900', marginTop: space.sm, textAlign: 'center'},
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
  errorState: {marginVertical: space.md, padding: space.xl, borderWidth: 1, borderColor: '#F2CBD0', backgroundColor: colors.dangerSoft, borderRadius: radius.lg, alignItems: 'center'},
  errorIcon: {width: 42, height: 42, borderRadius: 21, alignItems: 'center', justifyContent: 'center', backgroundColor: '#FFDDE1', marginBottom: space.sm},
  errorMark: {fontSize: 20, fontWeight: '900', color: colors.danger},
  errorTitle: {...type.bodyStrong, color: colors.danger, marginBottom: space.xs},
  statCard: {flex: 1, minWidth: 0, minHeight: 136, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.line, borderRadius: radius.lg, padding: space.md, ...shadowSoft},
  statIcon: {width: 36, height: 36, borderRadius: 12, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.primarySoft},
  statValue: {fontSize: 27, lineHeight: 32, fontWeight: '900', color: colors.text, marginTop: space.md},
  statLabel: {...type.caption, color: colors.muted, marginTop: 2},
});
