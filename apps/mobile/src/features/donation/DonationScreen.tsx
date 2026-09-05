import React from 'react';
import {FlatList, StyleSheet, Text, View} from 'react-native';
import {useQuery} from '@tanstack/react-query';
import {api, userMessage} from '../../api/client';
import {AppIcon} from '../../components/AppIcon';
import {AppHeader, Card, Empty, ErrorState, Loading, Muted, Screen} from '../../components/UI';
import {colors, radius, space, type} from '../../theme/tokens';
import type {Campaign, DonationHistoryItem} from '../../types/domain';
import {useAuth} from '../../store/auth';
import {formatCurrencyID, formatDonationStatus} from '../../utils/format';
import type {MainTabScreenProps} from '../../navigation/types';

export default function DonationScreen({navigation}: MainTabScreenProps<'Donasi'>) {
  const user = useAuth(s => s.user);
  const campaigns = useQuery({queryKey: ['campaigns'], queryFn: () => api<Campaign[]>('/api/v1/donation/campaigns')});
  const history = useQuery({queryKey: ['donation-history', user?.id], enabled: !!user, queryFn: () => api<DonationHistoryItem[]>('/api/v1/donations/history')});
  return (
    <Screen>
      <AppHeader eyebrow="DONASI" title="Kebaikan yang transparan" subtitle="Salurkan dukungan melalui campaign resmi. Status pembayaran selalu ditentukan backend Zabisa." />
      {user && history.data?.length ? <View style={styles.historyWrap}><Card><Text style={styles.title}>Riwayat donasi saya</Text>{history.data.slice(0, 3).map(item => <Text key={item.id} style={styles.history}>{formatCurrencyID(item.amount)} · {formatDonationStatus(item.status)} · {item.campaign_name}</Text>)}</Card></View> : null}
      {campaigns.isLoading ? <Loading label="Memuat campaign..." /> : null}
      {campaigns.isError ? <View style={styles.body}><ErrorState message={userMessage(campaigns.error)} onRetry={() => campaigns.refetch()} /></View> : null}
      {!campaigns.isLoading && !campaigns.isError ? (
        <FlatList contentContainerStyle={styles.list} data={campaigns.data ?? []} keyExtractor={item => item.id} ListEmptyComponent={<Empty icon="donation" text="Belum ada campaign aktif." />}
          renderItem={({item}) => {
            const progress = item.target_amount ? Math.min(100, (Number(item.collected_amount || 0) / Number(item.target_amount)) * 100) : 0;
            return <Card onPress={() => navigation.navigate('CampaignDetail', {campaign: item})}><View style={styles.cardLead}><AppIcon name="donation" size={21} background /><View style={styles.cardCopy}><Text style={styles.title}>{item.name}</Text><Muted>{item.category}</Muted></View><AppIcon name="chevronRight" size={18} color={colors.muted} /></View><Text style={styles.money}>{formatCurrencyID(item.collected_amount)}</Text>{item.target_amount ? <><View style={styles.progress}><View style={[styles.progressFill, {width: `${progress}%`}]} /></View><Muted>Target {formatCurrencyID(item.target_amount)}</Muted></> : null}</Card>;
          }} />
      ) : null}
    </Screen>
  );
}
const styles = StyleSheet.create({body: {paddingHorizontal: space.lg}, historyWrap: {paddingHorizontal: space.lg, paddingTop: space.sm}, list: {paddingHorizontal: space.lg, paddingTop: space.sm, paddingBottom: space.jumbo}, cardLead: {flexDirection: 'row', alignItems: 'center', gap: space.md}, cardCopy: {flex: 1}, title: {...type.bodyStrong, color: colors.text}, money: {fontSize: 22, lineHeight: 28, fontWeight: '900', color: colors.primary, marginTop: space.lg}, progress: {height: 8, backgroundColor: colors.surfaceMuted, borderRadius: radius.pill, overflow: 'hidden', marginVertical: space.sm}, progressFill: {height: '100%', backgroundColor: colors.primary}, history: {...type.caption, color: colors.muted, marginTop: space.sm}});
