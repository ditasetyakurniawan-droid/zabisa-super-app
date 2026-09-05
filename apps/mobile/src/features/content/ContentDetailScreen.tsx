import React from 'react';
import {StyleSheet, Text} from 'react-native';
import {useQuery} from '@tanstack/react-query';
import {api, userMessage} from '../../api/client';
import {DetailHeader, ErrorState, Loading, ScrollScreen} from '../../components/UI';
import {colors, space, type} from '../../theme/tokens';
import {contentTypeLabel} from '../../utils/content';
import type {ContentItem} from '../../types/domain';
import type {RootStackScreenProps} from '../../navigation/types';

export default function ContentDetailScreen({route}: RootStackScreenProps<'ContentDetail'>) {
  const query = useQuery({queryKey: ['content-detail', route.params.id], queryFn: () => api<ContentItem>(`/api/v1/content/${route.params.id}`)});
  if (query.isLoading) return <ScrollScreen safeTop={false}><Loading /></ScrollScreen>;
  if (query.isError) return <ScrollScreen safeTop={false}><ErrorState message={userMessage(query.error)} onRetry={() => query.refetch()} /></ScrollScreen>;
  if (!query.data) return <ScrollScreen safeTop={false}><ErrorState message="Konten tidak ditemukan." onRetry={() => query.refetch()} /></ScrollScreen>;
  const item = query.data;
  return (
    <ScrollScreen safeTop={false}>
      <DetailHeader eyebrow={contentTypeLabel(item.type)} title={item.title} subtitle={item.summary || undefined} icon="news" />
      <Text style={styles.body}>{item.body || 'Belum ada isi.'}</Text>
    </ScrollScreen>
  );
}

const styles = StyleSheet.create({
  body: {...type.body, color: colors.text, marginTop: space.xl},
});
