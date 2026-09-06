import React from 'react';
import {FlatList, StyleSheet, Text, View} from 'react-native';
import {useQuery} from '@tanstack/react-query';
import {api, userMessage} from '../../api/client';
import {AppIcon, type AppIconName} from '../../components/AppIcon';
import {AppHeader, Card, Empty, ErrorState, Loading, Muted, Screen} from '../../components/UI';
import {colors, space, type} from '../../theme/tokens';
import {contentTypeLabel, normalizeContentType} from '../../utils/content';
import type {ContentItem} from '../../types/domain';
import type {RootStackScreenProps} from '../../navigation/types';
import type {MascotVariant} from '../../components/Mascot';

function mascotForContent(contentKind: string): MascotVariant {
  switch (normalizeContentType(contentKind)) {
    case 'programs':
      return 'program';
    case 'gallery':
      return 'gallery';
    case 'profile':
      return 'about';
    case 'news':
    default:
      return 'news';
  }
}


function iconForContent(contentKind: string): AppIconName {
  switch (normalizeContentType(contentKind)) {
    case 'programs':
      return 'program';
    case 'gallery':
      return 'gallery';
    case 'profile':
      return 'info';
    case 'news':
    default:
      return 'news';
  }
}

function subtitleForContent(contentKind: string, title: string) {
  switch (normalizeContentType(contentKind)) {
    case 'programs':
      return 'Program kebaikan, pendidikan, dan karya yang dapat diikuti publik melalui Zabisa.';
    case 'gallery':
      return 'Dokumentasi momen belajar, kegiatan santri, dan atmosfer kebaikan di Zabisa.';
    case 'profile':
      return 'Kenali visi, adab, dan semangat belajar yang dibawa oleh Zabisa.';
    case 'news':
    default:
      return `Informasi ${title.toLowerCase()} yang dipublikasikan resmi melalui Zabisa.`;
  }
}

function contentEndpoint(contentType: string) {
  const query = contentType ? `?type=${encodeURIComponent(contentType)}` : '';
  return `/api/v1/content${query}`;
}

export default function ContentListScreen({navigation, route}: RootStackScreenProps<'ContentList'>) {
  const requestedType = route.params?.type || '';
  const contentType = normalizeContentType(requestedType);
  const title = route.params?.title || contentTypeLabel(contentType);
  const mascot = mascotForContent(contentType);
  const query = useQuery({
    queryKey: ['content', contentType],
    queryFn: () => api<ContentItem[]>(contentEndpoint(contentType)),
  });

  return (
    <Screen>
      <AppHeader mascot={mascot} eyebrow="INFORMASI PUBLIK" title={title} subtitle={subtitleForContent(contentType, title)} />
      {query.isLoading ? <Loading label={`Memuat ${title.toLowerCase()}...`} mascot={mascot} /> : null}
      {query.isError ? <View style={styles.body}><ErrorState message={userMessage(query.error)} onRetry={() => query.refetch()} mascot={mascot} /></View> : null}
      {!query.isLoading && !query.isError ? (
        <FlatList
          contentContainerStyle={styles.list}
          data={query.data ?? []}
          keyExtractor={item => item.id}
          ListHeaderComponent={<Card style={styles.infoCard}><Text style={styles.infoTitle}>Terbuka untuk publik</Text><Muted>{subtitleForContent(contentType, title)}</Muted></Card>}
          ListEmptyComponent={<Empty mascot={mascot} text={`Belum ada ${title.toLowerCase()} yang dipublikasikan.`} />}
          renderItem={({item}) => (
            <Card onPress={() => navigation.navigate('ContentDetail', {id: item.id, title: item.title})}>
              <View style={styles.cardLead}><AppIcon name={iconForContent(item.type)} size={21} background /><View style={styles.cardCopy}><Text style={styles.type}>{contentTypeLabel(item.type)}</Text><Text style={styles.title}>{item.title}</Text></View><AppIcon name="chevronRight" size={18} color={colors.muted} /></View>
              {item.summary ? <Muted style={styles.summary}>{item.summary}</Muted> : null}
              <Text style={styles.link}>Baca selengkapnya ›</Text>
            </Card>
          )}
        />
      ) : null}
    </Screen>
  );
}

const styles = StyleSheet.create({
  body: {paddingHorizontal: space.lg},
  list: {padding: space.lg, paddingTop: space.sm, paddingBottom: space.xxxl},
  infoCard: {backgroundColor: colors.primarySofter, borderColor: colors.primarySoft},
  infoTitle: {...type.bodyStrong, color: colors.primaryDeep, marginBottom: space.xs},
  cardLead: {flexDirection: 'row', alignItems: 'center', gap: space.md},
  cardCopy: {flex: 1},
  type: {...type.caption, color: colors.primary, fontWeight: '900', marginBottom: space.xs},
  title: {...type.bodyStrong, color: colors.text, marginBottom: space.xs},
  summary: {marginTop: space.md},
  link: {...type.caption, color: colors.primary, marginTop: space.md, fontWeight: '800'},
});
