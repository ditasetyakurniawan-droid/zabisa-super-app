import React from 'react';
import {Linking, StyleSheet, Text} from 'react-native';
import {Button, Card, DetailHeader, ScrollScreen, SectionTitle} from '../../components/UI';
import {colors, serviceColors, space, type} from '../../theme/tokens';
import type {RootStackScreenProps} from '../../navigation/types';

export default function KajianDetailScreen({route}: RootStackScreenProps<'KajianDetail'>) {
  const kajian = route.params.kajian;
  const mapURL = kajian.map_url;
  const liveURL = kajian.live_url;

  return (
    <ScrollScreen safeTop={false}>
      <DetailHeader eyebrow="Majelis ilmu" title={kajian.title} subtitle={kajian.speaker || 'Pemateri akan diumumkan'} icon="kajian" />
      <Card>
        <Text style={styles.label}>WAKTU</Text><Text style={styles.value}>{new Date(kajian.start_at).toLocaleString('id-ID')}</Text>
        <Text style={styles.label}>LOKASI</Text><Text style={styles.value}>{kajian.location || 'Lokasi menyusul'}</Text>
        {mapURL ? <Button secondary color={serviceColors.kajian.solid} softColor={serviceColors.kajian.soft} title="Buka peta" onPress={() => Linking.openURL(mapURL)} /> : null}
        {liveURL ? <Button secondary color={serviceColors.kajian.solid} softColor={serviceColors.kajian.soft} title="Buka live stream" onPress={() => Linking.openURL(liveURL)} /> : null}
      </Card>
      <SectionTitle>Deskripsi</SectionTitle>
      <Text style={styles.body}>{kajian.description || 'Deskripsi kajian belum tersedia.'}</Text>
    </ScrollScreen>
  );
}

const styles = StyleSheet.create({
  label: {...type.caption, color: colors.muted, fontWeight: '900', marginTop: space.sm},
  value: {...type.bodyStrong, color: colors.text, marginTop: 2, marginBottom: space.md},
  body: {...type.body, color: colors.text},
});
