import React from 'react';
import {Linking, StyleSheet, Text} from 'react-native';
import {Button, Card, ScrollScreen, SectionTitle, Title} from '../../components/UI';
import {colors, space, type} from '../../theme/tokens';

export default function KajianDetailScreen({route}: {route: any}) {
  const kajian = route.params.kajian;
  return (
    <ScrollScreen safeTop={false}>
      <Title>{kajian.title}</Title>
      <Text style={styles.speaker}>{kajian.speaker || 'Pemateri akan diumumkan'}</Text>
      <Card>
        <Text style={styles.label}>WAKTU</Text><Text style={styles.value}>{new Date(kajian.start_at).toLocaleString('id-ID')}</Text>
        <Text style={styles.label}>LOKASI</Text><Text style={styles.value}>{kajian.location || 'Lokasi menyusul'}</Text>
        {kajian.map_url ? <Button secondary title="Buka peta" onPress={() => Linking.openURL(kajian.map_url)} /> : null}
        {kajian.live_url ? <Button secondary title="Buka live stream" onPress={() => Linking.openURL(kajian.live_url)} /> : null}
      </Card>
      <SectionTitle>Deskripsi</SectionTitle>
      <Text style={styles.body}>{kajian.description || 'Deskripsi kajian belum tersedia.'}</Text>
    </ScrollScreen>
  );
}

const styles = StyleSheet.create({
  speaker: {...type.bodyStrong, color: colors.primary, marginTop: space.sm, marginBottom: space.lg},
  label: {...type.caption, color: colors.muted, fontWeight: '900', marginTop: space.sm},
  value: {...type.bodyStrong, color: colors.text, marginTop: 2, marginBottom: space.md},
  body: {...type.body, color: colors.text},
});
