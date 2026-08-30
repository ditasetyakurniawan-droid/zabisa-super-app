import React from 'react';
import {FlatList, Pressable, StyleSheet, Text, View} from 'react-native';
import {useQuery} from '@tanstack/react-query';
import {api, userMessage} from '../../api/client';
import {Card, Empty, ErrorState, HeroCard, IconTile, Loading, Muted, ScrollScreen, SectionTitle, TextButton} from '../../components/UI';
import {colors, radius, space, type} from '../../theme/tokens';
import type {Campaign, Kajian, Student} from '../../types/domain';
import {useAuth} from '../../store/auth';
import {formatCurrencyID, formatDateTimeID, friendlyFirstName} from '../../utils/format';

export default function HomeScreen({navigation}: {navigation: any}) {
  const user = useAuth(s => s.user);
  const guardian = !!user && ['GUARDIAN', 'WALI_SANTRI'].includes(user.role);
  const kajian = useQuery({queryKey: ['kajian'], queryFn: () => api<Kajian[]>('/api/v1/kajian')});
  const campaigns = useQuery({queryKey: ['campaigns'], queryFn: () => api<Campaign[]>('/api/v1/donation/campaigns')});
  const students = useQuery({queryKey: ['guardian-students', user?.id], enabled: guardian, queryFn: () => api<Student[]>('/api/v1/guardian/students')});
  const firstName = friendlyFirstName(user?.name);

  return (
    <ScrollScreen>
      <View style={styles.topBar}>
        <View>
          <Text style={styles.greet}>Assalamu'alaikum{firstName ? `, ${firstName}` : ''}</Text>
          <Text style={styles.brand}>Zabisa</Text>
        </View>
        <View style={styles.brandMark}><Text style={styles.brandMarkText}>Z</Text></View>
      </View>

      <HeroCard>
        <View style={styles.heroMetaRow}>
          <Text style={styles.heroEyebrow}>ZABISA PESANTREN</Text>
          {guardian ? <View style={styles.portalPill}><Text style={styles.portalPillText}>Portal wali aktif</Text></View> : null}
        </View>
        <Text style={styles.heroTitle}>Semua layanan pesantren dalam satu genggaman.</Text>
        <Text style={styles.heroBody}>Ikuti kajian, program, donasi, dan perkembangan santri dengan akses yang aman.</Text>
        {guardian && students.data?.length ? (
          <Pressable accessibilityRole="button" onPress={() => navigation.navigate('GuardianStudent', {student: students.data![0]})} style={({pressed}) => [styles.heroAction, pressed && styles.heroActionPressed]}>
            <Text style={styles.heroActionText}>Buka perkembangan ananda</Text>
            <Text style={styles.heroActionArrow}>›</Text>
          </Pressable>
        ) : null}
      </HeroCard>

      <View style={styles.actions}>
        <IconTile icon="donation" label="Donasi" onPress={() => navigation.navigate('Donasi')} />
        <IconTile icon="kajian" label="Kajian" onPress={() => navigation.navigate('Kajian')} />
        <IconTile icon="news" label="Berita" onPress={() => navigation.navigate('ContentList', {type: 'news', title: 'Berita'})} />
        <IconTile icon="program" label="Program" onPress={() => navigation.navigate('ContentList', {type: 'programs', title: 'Program'})} />
        <IconTile icon="info" label="Tentang" onPress={() => navigation.navigate('ContentList', {type: 'profile', title: 'Tentang Zabisa'})} />
        <IconTile icon="gallery" label="Galeri" onPress={() => navigation.navigate('ContentList', {type: 'gallery', title: 'Galeri'})} />
        <IconTile icon="notification" label="Notifikasi" onPress={() => navigation.navigate('Notifikasi')} />
        <IconTile icon="account" label="Akun" onPress={() => user ? navigation.navigate('Akun') : (navigation.getParent() as any)?.navigate('Login')} />
      </View>

      <SectionTitle action={<TextButton title="Lihat semua" onPress={() => navigation.navigate('Kajian')} />}>Kajian terbaru</SectionTitle>
      {kajian.isLoading ? <Loading label="Memuat kajian terbaru..." /> : null}
      {kajian.isError ? <ErrorState message={userMessage(kajian.error)} onRetry={() => kajian.refetch()} /> : null}
      {!kajian.isLoading && !kajian.isError && !kajian.data?.length ? <Empty icon="kajian" text="Belum ada kajian yang dipublikasikan." /> : null}
      {kajian.data?.slice(0, 2).map(item => (
        <Card key={item.id} onPress={() => navigation.navigate('KajianDetail', {kajian: item})}>
          <Text style={styles.cardTitle}>{item.title}</Text>
          <Text style={styles.primaryText}>{item.speaker || 'Pemateri akan diumumkan'}</Text>
          <Muted>{formatDateTimeID(item.start_at)}{item.location ? ` · ${item.location}` : ''}</Muted>
          <Text style={styles.cardLink}>Lihat detail ›</Text>
        </Card>
      ))}

      <SectionTitle action={<TextButton title="Lihat semua" onPress={() => navigation.navigate('Donasi')} />}>Program donasi</SectionTitle>
      {campaigns.isLoading ? <Loading label="Memuat program donasi..." /> : null}
      {campaigns.isError ? <ErrorState message={userMessage(campaigns.error)} onRetry={() => campaigns.refetch()} /> : null}
      {!campaigns.isLoading && !campaigns.isError && !campaigns.data?.length ? <Empty icon="donation" text="Belum ada campaign donasi aktif." /> : null}
      {campaigns.data?.length ? (
        <FlatList
          data={campaigns.data.slice(0, 4)}
          horizontal
          keyExtractor={item => item.id}
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.horizontalList}
          renderItem={({item}) => (
            <Card style={styles.campaign} onPress={() => navigation.navigate('CampaignDetail', {campaign: item})}>
              <Text style={styles.cardTitle}>{item.name}</Text>
              <Muted>{item.category}</Muted>
              <Text style={styles.money}>{formatCurrencyID(item.collected_amount)}</Text>
              <Text style={styles.target}>{item.target_amount ? `Target ${formatCurrencyID(item.target_amount)}` : 'Donasi terbuka'}</Text>
            </Card>
          )}
        />
      ) : null}
    </ScrollScreen>
  );
}

const styles = StyleSheet.create({
  topBar: {flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: space.xl},
  greet: {...type.caption, color: colors.muted, marginBottom: 1},
  brand: {fontSize: 30, lineHeight: 35, fontWeight: '900', color: colors.text, letterSpacing: -0.7},
  brandMark: {width: 46, height: 46, borderRadius: 16, backgroundColor: colors.primary, alignItems: 'center', justifyContent: 'center'},
  brandMarkText: {fontSize: 23, fontWeight: '900', color: colors.white},
  heroMetaRow: {flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: space.sm},
  heroEyebrow: {...type.micro, color: colors.onPrimaryMuted, flexShrink: 1},
  portalPill: {backgroundColor: 'rgba(255,255,255,0.15)', borderRadius: radius.pill, paddingHorizontal: 9, paddingVertical: 5},
  portalPillText: {...type.micro, color: colors.white, letterSpacing: 0},
  heroTitle: {fontSize: 27, lineHeight: 34, fontWeight: '900', color: colors.white, marginTop: space.md, maxWidth: 520},
  heroBody: {...type.body, color: colors.onPrimaryMuted, marginTop: space.md, maxWidth: 520},
  heroAction: {minHeight: 48, marginTop: space.xl, borderRadius: radius.md, backgroundColor: 'rgba(255,255,255,0.15)', paddingHorizontal: space.lg, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between'},
  heroActionPressed: {backgroundColor: 'rgba(255,255,255,0.22)'},
  heroActionText: {...type.caption, color: colors.white, fontWeight: '900'},
  heroActionArrow: {fontSize: 25, color: colors.white, marginLeft: space.md},
  actions: {flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between', rowGap: space.md, marginTop: space.xl},
  cardTitle: {...type.bodyStrong, color: colors.text, marginBottom: space.xs},
  primaryText: {...type.caption, color: colors.primary, marginBottom: space.xs},
  cardLink: {...type.caption, color: colors.primary, fontWeight: '900', marginTop: space.md},
  horizontalList: {paddingRight: space.lg},
  campaign: {width: 245, marginRight: space.md},
  money: {fontSize: 20, fontWeight: '900', color: colors.primary, marginTop: space.md},
  target: {...type.caption, color: colors.muted, marginTop: 2},
});
