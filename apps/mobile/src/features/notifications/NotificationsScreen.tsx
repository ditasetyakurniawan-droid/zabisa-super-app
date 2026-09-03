import React from 'react';
import {FlatList, StyleSheet, Text, View} from 'react-native';
import {useMutation, useQuery, useQueryClient} from '@tanstack/react-query';
import {api, userMessage} from '../../api/client';
import {AppHeader, Card, Empty, ErrorState, Loading, Muted, Pill, Screen, SectionTitle, TextButton} from '../../components/UI';
import {colors, space, type} from '../../theme/tokens';
import {useAuth} from '../../store/auth';
import type {NotificationItem, Student} from '../../types/domain';
import {formatDateTimeID} from '../../utils/format';
import {notificationTypeLabel, parseZabisaDeepLink} from './deepLink';
import type {MainTabScreenProps} from '../../navigation/types';

function tone(typeName: string) {
  if (typeName === 'TAHFIDZ') return 'success' as const;
  if (typeName === 'GRADE' || typeName === 'ACADEMIC') return 'primary' as const;
  return 'neutral' as const;
}

export default function NotificationsScreen({navigation}: MainTabScreenProps<'Notifikasi'>) {
  const queryClient = useQueryClient();
  const user = useAuth(s => s.user);
  const guardian = !!user && ['GUARDIAN', 'WALI_SANTRI'].includes(user.role);
  const query = useQuery({queryKey: ['notifications', user?.id], enabled: !!user, queryFn: () => api<NotificationItem[]>('/api/v1/notifications')});
  const students = useQuery({queryKey: ['guardian-students', user?.id], enabled: guardian, queryFn: () => api<Student[]>('/api/v1/guardian/students')});
  const unreadCount = query.data?.filter(item => !item.read).length ?? 0;

  const markRead = useMutation({
    mutationFn: (id: string) => api<void>(`/api/v1/notifications/${id}/read`, {method: 'PATCH'}),
    onSuccess: () => queryClient.invalidateQueries({queryKey: ['notifications', user?.id]}),
  });
  const markAllRead = useMutation({
    mutationFn: () => api<void>('/api/v1/notifications/read-all', {method: 'PATCH'}),
    onSuccess: () => queryClient.invalidateQueries({queryKey: ['notifications', user?.id]}),
  });

  async function openNotification(item: NotificationItem) {
    if (!item.read) markRead.mutate(item.id);
    const parsed = parseZabisaDeepLink(item.deep_link);
    if (parsed.kind === 'kajian' || item.type === 'KAJIAN') {
      navigation.navigate('Kajian');
      return;
    }
    if (!guardian) return;
    const student = parsed.kind === 'guardian'
      ? students.data?.find(value => value.id === parsed.studentId)
      : students.data?.length === 1 ? students.data[0] : undefined;
    if (student && (parsed.kind === 'guardian' || parsed.kind === 'legacy-guardian' || ['TAHFIDZ', 'ACADEMIC', 'GRADE'].includes(item.type))) {
      navigation.navigate('GuardianStudent', {student});
      return;
    }
    if (['TAHFIDZ', 'ACADEMIC', 'GRADE'].includes(item.type)) navigation.navigate('GuardianOverview');
  }

  return (
    <Screen>
      <AppHeader eyebrow="INBOX" title="Notifikasi" subtitle="Informasi penting tetap tersimpan meskipun push notification terlewat." />
      {!user ? <View style={styles.body}><Empty icon="notification" text="Login melalui menu Akun untuk melihat notifikasi pribadi." /></View> : null}
      {user && query.isLoading ? <Loading label="Memuat notifikasi..." /> : null}
      {user && query.isError ? <View style={styles.body}><ErrorState message={userMessage(query.error)} onRetry={() => query.refetch()} /></View> : null}
      {user && !query.isLoading && !query.isError ? (
        <FlatList
          contentContainerStyle={styles.list}
          data={query.data ?? []}
          keyExtractor={item => item.id}
          ListHeaderComponent={query.data?.length ? (
            <SectionTitle action={unreadCount ? <TextButton title={markAllRead.isPending ? 'Memproses...' : 'Tandai dibaca'} onPress={() => markAllRead.mutate()} /> : undefined}>
              {unreadCount ? `${unreadCount} belum dibaca` : 'Semua sudah dibaca'}
            </SectionTitle>
          ) : undefined}
          ListEmptyComponent={<Empty icon="notification" text="Belum ada notifikasi." />}
          renderItem={({item}) => (
            <Card style={!item.read ? styles.unreadCard : undefined} onPress={() => openNotification(item)}>
              <View style={styles.row}><Pill tone={tone(item.type)} text={notificationTypeLabel(item.type)} />{!item.read ? <View accessibilityLabel="Belum dibaca" style={styles.unreadDot} /> : null}</View>
              <Text style={styles.title}>{item.title}</Text>
              <Text style={styles.message}>{item.message}</Text>
              <Muted>{formatDateTimeID(item.created_at)}</Muted>
            </Card>
          )}
        />
      ) : null}
    </Screen>
  );
}

const styles = StyleSheet.create({
  body: {paddingHorizontal: space.lg},
  list: {paddingHorizontal: space.lg, paddingTop: 0, paddingBottom: 100},
  row: {flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between'},
  unreadDot: {width: 9, height: 9, borderRadius: 5, backgroundColor: colors.sky},
  unreadCard: {borderColor: colors.lineStrong, backgroundColor: colors.primarySofter},
  title: {...type.bodyStrong, color: colors.text, marginTop: space.md, marginBottom: space.xs},
  message: {...type.body, color: colors.textSoft, marginBottom: space.sm},
});
