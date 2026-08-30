import React from 'react';
import {StyleSheet, Text, View} from 'react-native';
import {AppHeader, Button, Card, Muted, ScrollScreen, TextField} from '../../components/UI';
import {colors, radius, space, type} from '../../theme/tokens';
import {useAuth} from '../../store/auth';
import {userMessage} from '../../api/client';

export default function LoginScreen({navigation}: {navigation: any}) {
  const login = useAuth(s => s.login);
  const busy = useAuth(s => s.busy);
  const user = useAuth(s => s.user);
  const [email, setEmail] = React.useState(__DEV__ ? 'guardian@zabisa.local' : '');
  const [password, setPassword] = React.useState(__DEV__ ? 'ChangeMe123!' : '');
  const [error, setError] = React.useState('');

  React.useEffect(() => {
    if (user) navigation.reset({index: 0, routes: [{name: 'Main', params: {screen: 'Akun'}}]});
  }, [navigation, user]);

  async function doLogin() {
    setError('');
    if (!email.trim() || !password) {
      setError('Email dan password wajib diisi.');
      return;
    }
    try {
      await login(email, password);
    } catch (err) {
      setError(userMessage(err));
    }
  }

  return (
    <ScrollScreen safeTop={false} contentStyle={styles.content}>
      <View style={styles.brandRow}>
        <View style={styles.brandMark}><Text style={styles.brandMarkText}>Z</Text></View>
        <View style={styles.brandCopy}>
          <Text style={styles.brand}>Zabisa</Text>
          <Muted>Portal digital pesantren</Muted>
        </View>
      </View>
      <AppHeader eyebrow="PORTAL WALI SANTRI" title="Selamat datang kembali" subtitle="Masuk untuk melihat perkembangan ananda secara privat dan aman." />
      <View style={styles.loginCard}>
        <Text style={styles.loginTitle}>Masuk ke akun</Text>
        <TextField label="Email" value={email} onChangeText={setEmail} autoCapitalize="none" autoCorrect={false} keyboardType="email-address" textContentType="username" placeholder="nama@email.com" />
        <TextField label="Password" value={password} onChangeText={setPassword} secureTextEntry secureToggle textContentType="password" autoCapitalize="none" autoCorrect={false} placeholder="Masukkan password" onSubmitEditing={doLogin} returnKeyType="done" />
        {error ? <View style={styles.errorBox}><Text style={styles.error}>{error}</Text></View> : null}
        <Button disabled={busy} title={busy ? 'Memverifikasi...' : 'Masuk'} onPress={doLogin} />
        <Text style={styles.securityNote}>Akses sesi disimpan melalui Keychain / Android Keystore.</Text>
      </View>
      {__DEV__ ? (
        <Card style={styles.devCard}>
          <Text style={styles.devLabel}>DATA LOGIN PENGEMBANGAN</Text>
          <Muted>guardian@zabisa.local · ChangeMe123!</Muted>
        </Card>
      ) : null}
    </ScrollScreen>
  );
}

const styles = StyleSheet.create({
  content: {paddingTop: space.md},
  brandRow: {flexDirection: 'row', alignItems: 'center', marginBottom: space.md},
  brandMark: {width: 48, height: 48, borderRadius: 17, backgroundColor: colors.primary, alignItems: 'center', justifyContent: 'center', marginRight: space.md},
  brandMarkText: {fontSize: 23, fontWeight: '900', color: colors.white},
  brandCopy: {flex: 1},
  brand: {fontSize: 22, lineHeight: 27, fontWeight: '900', color: colors.text},
  loginCard: {backgroundColor: colors.surface, borderRadius: radius.xl, borderWidth: 1, borderColor: colors.line, padding: space.lg, marginTop: space.sm},
  loginTitle: {...type.section, color: colors.text, marginBottom: space.lg},
  errorBox: {backgroundColor: colors.dangerSoft, borderRadius: radius.md, padding: space.md, marginBottom: space.sm},
  error: {...type.caption, color: colors.danger},
  securityNote: {...type.micro, color: colors.muted, textAlign: 'center', marginTop: space.md},
  devCard: {backgroundColor: colors.accentSoft, borderColor: colors.accentLine},
  devLabel: {...type.micro, color: colors.warning, fontWeight: '900', marginBottom: space.xs},
});
