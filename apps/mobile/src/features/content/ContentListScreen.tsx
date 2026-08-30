import React from 'react';
import {FlatList, StyleSheet, Text, View} from 'react-native';
import {useQuery} from '@tanstack/react-query';
import {api, userMessage} from '../../api/client';
import {Card, Empty, ErrorState, Loading, Muted, Screen, Title} from '../../components/UI';
import {colors, space, type} from '../../theme/tokens';
import {contentTypeLabel, normalizeContentType} from '../../utils/content';

export default function ContentListScreen({navigation, route}: {navigation: any; route: any}) {
  const requestedType = route.params?.type || '';
  const contentType = normalizeContentType(requestedType);
  const title = route.params?.title || contentTypeLabel(contentType);
  const query = useQuery({
    queryKey: ['content', contentType],
    queryFn: () => api<any[]>(`/api/v1/content${contentType ? `?type=${encodeURIComponent(contentType)}` : ''}`),
  });

  return (
    <Screen>
      <View style={styles.header}>
        <Title>{title}</Title>
        <Muted>Informasi resmi yang dipublikasikan melalui Zabisa Backoffice.</Muted>
      </View>
      {query.isLoading ? <Loading /> : null}
      {query.isError ? <View style={styles.body}><ErrorState message={userMessage(query.error)} onRetry={() => query.refetch()} /></View> : null}
      {!query.isLoading && !query.isError ? (
        <FlatList
          contentContainerStyle={styles.list}
          data={query.data ?? []}
          keyExtractor={item => item.id}
          ListEmptyComponent={<Empty text={`Belum ada ${title.toLowerCase()} yang dipublikasikan.`} />}
          renderItem={({item}) => (
            <Card onPress={() => navigation.navigate('ContentDetail', {id: item.id, title: item.title})}>
              <Text style={styles.type}>{contentTypeLabel(item.type)}</Text>
              <Text style={styles.title}>{item.title}</Text>
              {item.summary ? <Muted>{item.summary}</Muted> : null}
              <Text style={styles.link}>Baca selengkapnya ›</Text>
            </Card>
          )}
        />
      ) : null}
    </Screen>
  );
}

const styles = StyleSheet.create({
  header: {paddingHorizontal: space.lg, paddingTop: space.lg},
  body: {paddingHorizontal: space.lg},
  list: {padding: space.lg, paddingBottom: space.xxxl},
  type: {...type.caption, color: colors.primary, fontWeight: '900', marginBottom: space.xs},
  title: {...type.bodyStrong, color: colors.text, marginBottom: space.xs},
  link: {...type.caption, color: colors.primary, marginTop: space.md, fontWeight: '800'},
});
