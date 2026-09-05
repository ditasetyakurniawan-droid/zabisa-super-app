import React from 'react';
import {StyleSheet, Text} from 'react-native';
import {useQuery} from '@tanstack/react-query';
import {api, userMessage} from '../../api/client';
import {Button, Card, DetailHeader, Empty, ErrorState, Loading, Muted, ScrollScreen, SectionTitle} from '../../components/UI';
import {colors, serviceColors, space, type} from '../../theme/tokens';
import type {CampaignUpdate} from '../../types/domain';
import type {RootStackScreenProps} from '../../navigation/types';

export default function CampaignDetailScreen({navigation, route}: RootStackScreenProps<'CampaignDetail'>) {
  const campaign = route.params.campaign;
  const updates = useQuery({queryKey: ['campaign-updates', campaign.id], queryFn: () => api<CampaignUpdate[]>(`/api/v1/donation/campaigns/${campaign.id}/updates`)});
  return (
    <ScrollScreen safeTop={false}>
      <DetailHeader eyebrow="Program kebaikan" title={campaign.name} subtitle={campaign.category} icon="donation" />
      <Card style={styles.summary}>
        <Text style={styles.label}>TERKUMPUL</Text>
        <Text style={styles.money}>Rp {Number(campaign.collected_amount || 0).toLocaleString('id-ID')}</Text>
        {campaign.target_amount ? <Muted>Target Rp {Number(campaign.target_amount).toLocaleString('id-ID')}</Muted> : null}
        <Button color={serviceColors.donation.solid} softColor={serviceColors.donation.soft} title="Donasi sekarang" icon="donation" onPress={() => navigation.navigate('DonationCheckout', {campaign})} />
      </Card>
      <SectionTitle>Tentang campaign</SectionTitle>
      <Text style={styles.body}>{campaign.description || 'Deskripsi campaign belum tersedia.'}</Text>
      <SectionTitle>Update campaign</SectionTitle>
      {updates.isLoading ? <Loading /> : null}
      {updates.isError ? <ErrorState message={userMessage(updates.error)} onRetry={() => updates.refetch()} /> : null}
      {!updates.isLoading && !updates.isError && !updates.data?.length ? <Empty icon="info" text="Belum ada update campaign." /> : null}
      {updates.data?.map(item => <Card key={item.id}><Text style={styles.updateTitle}>{item.title}</Text><Text style={styles.body}>{item.body}</Text><Muted>{new Date(item.created_at).toLocaleString('id-ID')}</Muted></Card>)}
    </ScrollScreen>
  );
}

const styles = StyleSheet.create({
  summary: {marginTop: space.lg},
  label: {...type.caption, color: colors.muted, fontWeight: '900'},
  money: {fontSize: 27, lineHeight: 34, fontWeight: '900', color: serviceColors.donation.solid, marginVertical: space.sm},
  body: {...type.body, color: colors.text},
  updateTitle: {...type.bodyStrong, color: colors.text, marginBottom: space.sm},
});
