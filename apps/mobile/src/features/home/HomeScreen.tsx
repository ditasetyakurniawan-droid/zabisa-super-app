import React from 'react';
import {FlatList, Image, Pressable, StyleSheet, Text, View} from 'react-native';
import {useQuery} from '@tanstack/react-query';
import {api, userMessage} from '../../api/client';
import {Card, Empty, ErrorState, HeroCard, IconTile, Loading, Muted, ScrollScreen, SectionTitle, TextButton} from '../../components/UI';
import {colors, radius, serviceColors, shadowSoft, space, type} from '../../theme/tokens';
import type {Campaign, Kajian, Student} from '../../types/domain';
import {useAuth} from '../../store/auth';
import {formatCurrencyID, formatDateTimeID, friendlyFirstName} from '../../utils/format';
import type {MainTabScreenProps} from '../../navigation/types';

export default function HomeScreen({navigation}: MainTabScreenProps<'Home'>) {
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
          <View style={styles.brandRow}><Text style={styles.brand}>Zabisa</Text><View style={styles.onlinePill}><View style={styles.onlineDot} /><Text style={styles.onlineText}>Ruang santri</Text></View></View>
        </View>
        <View style={styles.brandMark}><Text style={styles.brandMarkText}>Z</Text><View style={styles.brandMarkDot} /></View>
      </View>

      <HeroCard>
        <View style={styles.heroCopy}>
          <View style={styles.heroMetaRow}>
            <View style={styles.heroEyebrowPill}><View style={styles.heroEyebrowDot} /><Text style={styles.heroEyebrow}>BERSAMA AL-QUR'AN</Text></View>
          </View>
          <Text style={styles.heroTitle}>Ilmu tumbuh. Adab berlabuh.</Text>
          <Text style={styles.heroBody}>Dekat dengan perjalanan santri dan kebaikan Zabisa, setiap hari.</Text>
          {guardian && students.data?.length ? (
            <Pressable accessibilityRole="button" onPress={() => navigation.navigate('GuardianStudent', {student: students.data![0]})} style={({pressed}) => [styles.heroAction, pressed && styles.heroActionPressed]}>
              <Text style={styles.heroActionText}>Lihat ananda</Text>
              <Text style={styles.heroActionArrow}>›</Text>
            </Pressable>
          ) : null}
        </View>
        <View pointerEvents="none" style={styles.mascotGlow} />
        <Image accessibilityIgnoresInvertColors source={require('../../assets/zabisa-quran-mascot.png')} resizeMode="contain" style={styles.mascot} />
        <View pointerEvents="none" style={styles.heroGoldLine} />
      </HeroCard>

      <SectionTitle>Layanan pilihan</SectionTitle>
      <View style={styles.actions}>
        <IconTile icon="donation" label="Berbagi" subtitle="Donasi" color={serviceColors.donation.solid} softColor={serviceColors.donation.soft} onPress={() => navigation.navigate('Donasi')} />
        <IconTile icon="kajian" label="Majelis Ilmu" subtitle="Kajian" color={serviceColors.kajian.solid} softColor={serviceColors.kajian.soft} onPress={() => navigation.navigate('Kajian')} />
        <IconTile icon="news" label="Kabar Zabisa" subtitle="Berita" color={serviceColors.news.solid} softColor={serviceColors.news.soft} onPress={() => navigation.navigate('ContentList', {type: 'news', title: 'Berita'})} />
        <IconTile icon="program" label="Jejak Karya" subtitle="Program" color={serviceColors.program.solid} softColor={serviceColors.program.soft} onPress={() => navigation.navigate('ContentList', {type: 'programs', title: 'Program'})} />
        <IconTile icon="info" label="Mengenal Kami" subtitle="Tentang" color={serviceColors.info.solid} softColor={serviceColors.info.soft} onPress={() => navigation.navigate('ContentList', {type: 'profile', title: 'Tentang Zabisa'})} />
        <IconTile icon="gallery" label="Momen Santri" subtitle="Galeri" color={serviceColors.gallery.solid} softColor={serviceColors.gallery.soft} onPress={() => navigation.navigate('ContentList', {type: 'gallery', title: 'Galeri'})} />
        <IconTile icon="notification" label="Amanah Baru" subtitle="Notifikasi" color={serviceColors.notification.solid} softColor={serviceColors.notification.soft} onPress={() => navigation.navigate('Notifikasi')} />
        <IconTile icon="account" label="Ruang Pribadi" subtitle="Akun" color={serviceColors.account.solid} softColor={serviceColors.account.soft} onPress={() => user ? navigation.navigate('Akun') : navigation.navigate('Login')} />
      </View>

      <SectionTitle action={<TextButton title="Lihat semua" onPress={() => navigation.navigate('Kajian')} />}>Majelis ilmu terbaru</SectionTitle>
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

      <SectionTitle action={<TextButton title="Lihat semua" onPress={() => navigation.navigate('Donasi')} />}>Jalan kebaikan</SectionTitle>
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
  topBar: {flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: space.lg, paddingVertical: space.sm},
  greet: {...type.caption, color: colors.muted, marginBottom: 2},
  brandRow: {flexDirection: 'row', alignItems: 'center'},
  brand: {fontSize: 30, lineHeight: 35, fontWeight: '900', color: colors.text, letterSpacing: -0.8},
  onlinePill: {flexDirection: 'row', alignItems: 'center', marginLeft: space.md, backgroundColor: colors.primarySofter, borderRadius: radius.pill, paddingHorizontal: 9, paddingVertical: 5},
  onlineDot: {width: 6, height: 6, borderRadius: 3, backgroundColor: colors.sky, marginRight: 5},
  onlineText: {...type.micro, color: colors.primary, letterSpacing: 0},
  brandMark: {width: 48, height: 48, borderRadius: 17, backgroundColor: colors.primary, alignItems: 'center', justifyContent: 'center', ...shadowSoft},
  brandMarkText: {fontSize: 22, fontWeight: '900', color: colors.white},
  brandMarkDot: {position: 'absolute', right: 5, top: 5, width: 7, height: 7, borderRadius: 4, backgroundColor: colors.accent},
  heroCopy: {width: '62%', minHeight: 214, zIndex: 5},
  heroMetaRow: {flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: space.sm},
  heroEyebrowPill: {flexDirection: 'row', alignItems: 'center', backgroundColor: colors.onPrimarySurface, borderRadius: radius.pill, paddingHorizontal: 9, paddingVertical: 6},
  heroEyebrowDot: {width: 6, height: 6, borderRadius: 3, backgroundColor: colors.accent, marginRight: 6},
  heroEyebrow: {...type.micro, color: colors.white, flexShrink: 1, letterSpacing: 0.45},
  heroTitle: {fontSize: 23, lineHeight: 29, fontWeight: '900', color: colors.white, marginTop: space.md, letterSpacing: -0.4},
  heroBody: {fontSize: 12.5, lineHeight: 19, fontWeight: '500', color: colors.onPrimaryMuted, marginTop: space.sm},
  heroAction: {minHeight: 44, marginTop: space.md, borderRadius: radius.md, backgroundColor: colors.white, paddingHorizontal: space.md, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between'},
  heroActionPressed: {backgroundColor: colors.onPrimarySurfacePressed},
  heroActionText: {...type.caption, color: colors.primaryDeep, fontWeight: '900'},
  heroActionArrow: {fontSize: 23, color: colors.primary, marginLeft: space.md},
  mascotGlow: {position: 'absolute', right: -42, bottom: -54, width: 220, height: 220, borderRadius: 110, backgroundColor: colors.sky, opacity: 0.24},
  mascot: {position: 'absolute', right: -31, bottom: -95, width: 205, height: 310, zIndex: 4},
  heroGoldLine: {position: 'absolute', right: 23, top: 22, width: 35, height: 4, borderRadius: radius.pill, backgroundColor: colors.accent, opacity: 0.9},
  actions: {flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between', rowGap: space.md},
  cardTitle: {...type.bodyStrong, color: colors.text, marginBottom: space.xs},
  primaryText: {...type.caption, color: serviceColors.kajian.solid, marginBottom: space.xs},
  cardLink: {...type.caption, color: colors.primary, fontWeight: '900', marginTop: space.md},
  horizontalList: {paddingRight: space.lg},
  campaign: {width: 245, marginRight: space.md},
  money: {fontSize: 20, fontWeight: '900', color: serviceColors.donation.solid, marginTop: space.md},
  target: {...type.caption, color: colors.muted, marginTop: 2},
});
