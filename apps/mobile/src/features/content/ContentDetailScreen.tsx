import React from 'react';
import {StyleSheet, Text} from 'react-native';
import {useQuery} from '@tanstack/react-query';
import {api, userMessage} from '../../api/client';
import {DetailHeader, ErrorState, Loading, ScrollScreen} from '../../components/UI';
import {colors, space, type} from '../../theme/tokens';
import {contentTypeLabel, normalizeContentType} from '../../utils/content';
import type {ContentItem} from '../../types/domain';
import type {RootStackScreenProps} from '../../navigation/types';
import type {AppIconName} from '../../components/AppIcon';
import type {MascotVariant} from '../../components/Mascot';

function contentVisual(contentKind: string): {icon: AppIconName; mascot: MascotVariant} {
  switch (normalizeContentType(contentKind)) {
    case 'programs':
      return {icon: 'program', mascot: 'program'};
    case 'gallery':
      return {icon: 'gallery', mascot: 'gallery'};
    case 'profile':
      return {icon: 'info', mascot: 'about'};
    case 'news':
    default:
      return {icon: 'news', mascot: 'news'};
  }
}

export default function ContentDetailScreen({route}: RootStackScreenProps<'ContentDetail'>) {
  const fallbackTitle = route.params.title || 'Informasi';
  const query = useQuery({queryKey: ['content-detail', route.params.id], queryFn: () => api<ContentItem>(`/api/v1/content/${route.params.id}`)});
  if (query.isLoading) return <ScrollScreen safeTop={false}><Loading label={`Memuat ${fallbackTitle.toLowerCase()}...`} mascot="news" /></ScrollScreen>;
  if (query.isError) return <ScrollScreen safeTop={false}><ErrorState message={userMessage(query.error)} onRetry={() => query.refetch()} mascot="news" /></ScrollScreen>;
  if (!query.data) return <ScrollScreen safeTop={false}><ErrorState message="Konten tidak ditemukan." onRetry={() => query.refetch()} mascot="news" /></ScrollScreen>;
  const item = query.data;
  const visual = contentVisual(item.type);
  return (
    <ScrollScreen safeTop={false}>
      <DetailHeader eyebrow={contentTypeLabel(item.type)} title={item.title} subtitle={item.summary || 'Informasi publik dari Zabisa.'} icon={visual.icon} mascot={visual.mascot} />
      <Text style={styles.body}>{item.body || 'Belum ada isi.'}</Text>
    </ScrollScreen>
  );
}

const styles = StyleSheet.create({
  body: {...type.body, color: colors.text, marginTop: space.xl},
});
