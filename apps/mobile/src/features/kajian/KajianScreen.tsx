import React from 'react';
import {FlatList, StyleSheet, Text, View} from 'react-native';
import {useQuery} from '@tanstack/react-query';
import {api, userMessage} from '../../api/client';
import {AppIcon} from '../../components/AppIcon';
import {AppHeader, Card, Empty, ErrorState, Loading, Muted, Screen} from '../../components/UI';
import {colors, space, type} from '../../theme/tokens';
import type {Kajian} from '../../types/domain';
import {formatDateTimeID} from '../../utils/format';
import type {MainTabScreenProps} from '../../navigation/types';

export default function KajianScreen({navigation}: MainTabScreenProps<'Kajian'>) {
  const query = useQuery({queryKey: ['kajian'], queryFn: () => api<Kajian[]>('/api/v1/kajian')});
  return (
    <Screen>
      <AppHeader eyebrow="KAJIAN & EVENT" title="Temukan majelis ilmu" subtitle="Jadwal, lokasi, pemateri, dan live stream yang dipublikasikan resmi oleh Zabisa." />
      {query.isLoading ? <Loading label="Memuat kajian..." /> : null}
      {query.isError ? <View style={styles.body}><ErrorState message={userMessage(query.error)} onRetry={() => query.refetch()} /></View> : null}
      {!query.isLoading && !query.isError ? (
        <FlatList contentContainerStyle={styles.list} data={query.data ?? []} keyExtractor={item => item.id} ListEmptyComponent={<Empty icon="kajian" text="Belum ada kajian yang dipublikasikan." />}
          renderItem={({item}) => (
            <Card onPress={() => navigation.navigate('KajianDetail', {kajian: item})}>
              <View style={styles.row}>
                <AppIcon name="kajian" size={22} background />
                <View style={styles.copy}>
                  <Text style={styles.title}>{item.title}</Text><Text style={styles.speaker}>{item.speaker || 'Pemateri akan diumumkan'}</Text>
                  <Muted>{formatDateTimeID(item.start_at)}</Muted><Muted>{item.location || 'Lokasi menyusul'}</Muted>
                </View>
                <AppIcon name="chevronRight" size={18} color={colors.muted} />
              </View>
            </Card>
          )} />
      ) : null}
    </Screen>
  );
}
const styles = StyleSheet.create({body: {paddingHorizontal: space.lg}, list: {paddingHorizontal: space.lg, paddingTop: space.sm, paddingBottom: space.jumbo}, row: {flexDirection: 'row', alignItems: 'center', gap: space.md}, copy: {flex: 1}, title: {...type.bodyStrong, color: colors.text, marginBottom: space.xs}, speaker: {...type.caption, color: colors.primary, fontWeight: '800', marginBottom: space.sm}});
