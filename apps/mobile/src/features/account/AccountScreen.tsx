import React from 'react';
import {StyleSheet, Text, View} from 'react-native';
import {AppHeader, Button, Card, Muted, ScrollScreen, SectionTitle} from '../../components/UI';
import {colors, radius, space, type} from '../../theme/tokens';
import {useAuth} from '../../store/auth';
import type {MainTabScreenProps} from '../../navigation/types';

export default function AccountScreen({navigation}: MainTabScreenProps<'Akun'>) {
  const user = useAuth(s => s.user);
  const logout = useAuth(s => s.logout);
  const busy = useAuth(s => s.busy);

  if (!user) {
    return (
      <ScrollScreen contentStyle={styles.noTopPadding}>
        <AppHeader eyebrow="AKUN" title="Masuk ke Zabisa" subtitle="Gunakan akun wali santri untuk membuka layanan privat." />
        <Card>
          <Text style={styles.cardTitle}>Akses wali santri</Text>
          <Muted>Login diperlukan untuk melihat tahfidz, nilai, kehadiran, report, dan notifikasi pribadi.</Muted>
          <Button title="Masuk" onPress={() => navigation.navigate('Login')} />
        </Card>
      </ScrollScreen>
    );
  }

  const guardian = ['GUARDIAN', 'WALI_SANTRI'].includes(user.role);
  return (
    <ScrollScreen contentStyle={styles.noTopPadding}>
      <AppHeader eyebrow="AKUN SAYA" title="Profil & keamanan" subtitle="Kelola akses pribadi Anda ke layanan Zabisa." />
      <Card style={styles.profileCard}>
        <View style={styles.avatar}><Text style={styles.avatarText}>{(user.name || user.email).slice(0, 1).toUpperCase()}</Text></View>
        <View style={styles.profileCopy}>
          <Text style={styles.name}>{user.name || 'Pengguna Zabisa'}</Text>
          <Muted>{user.email}</Muted>
          <View style={styles.rolePill}><Text style={styles.role}>{guardian ? 'Wali Santri' : user.role}</Text></View>
        </View>
      </Card>
      {guardian ? (
        <>
          <SectionTitle>Portal wali santri</SectionTitle>
          <Card>
            <Text style={styles.cardTitle}>Perkembangan ananda</Text>
            <Muted>Lihat tahfidz, nilai, kehadiran, dan report dari santri yang terhubung.</Muted>
            <Button title="Buka data ananda" icon="tahfidz" onPress={() => navigation.navigate('GuardianOverview')} />
          </Card>
        </>
      ) : null}
      <SectionTitle>Keamanan perangkat</SectionTitle>
      <Card>
        <Text style={styles.cardTitle}>Sesi terlindungi</Text>
        <Muted>Token sesi disimpan melalui Keychain / Android Keystore. Keluar akan menghapus sesi lokal perangkat ini.</Muted>
        <Button secondary disabled={busy} title={busy ? 'Memproses...' : 'Keluar dari akun'} onPress={() => logout()} />
      </Card>
    </ScrollScreen>
  );
}

const styles = StyleSheet.create({
  noTopPadding: {paddingTop: 0},
  profileCard: {marginTop: space.sm, flexDirection: 'row', alignItems: 'center'},
  avatar: {width: 60, height: 60, borderRadius: 20, backgroundColor: colors.primarySoft, alignItems: 'center', justifyContent: 'center', marginRight: space.md},
  avatarText: {fontSize: 24, fontWeight: '900', color: colors.primary},
  profileCopy: {flex: 1},
  name: {fontSize: 20, lineHeight: 26, fontWeight: '900', color: colors.text, marginBottom: 2},
  rolePill: {alignSelf: 'flex-start', marginTop: space.sm, backgroundColor: colors.primarySoft, borderRadius: radius.pill, paddingHorizontal: 10, paddingVertical: 5},
  role: {...type.caption, color: colors.primary, fontWeight: '900'},
  cardTitle: {...type.bodyStrong, color: colors.text, marginBottom: space.xs},
});
