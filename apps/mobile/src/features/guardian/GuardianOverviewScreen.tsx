import React from 'react';
import {StyleSheet, Text, View} from 'react-native';
import {useQuery} from '@tanstack/react-query';
import {api, userMessage} from '../../api/client';
import {AppIcon} from '../../components/AppIcon';
import {AppHeader, Card, Empty, ErrorState, Loading, Muted, ScrollScreen} from '../../components/UI';
import {colors, space, type} from '../../theme/tokens';
import type {Student} from '../../types/domain';
import type {RootStackScreenProps} from '../../navigation/types';

export default function GuardianOverviewScreen({navigation}: RootStackScreenProps<'GuardianOverview'>) {
  const students = useQuery({queryKey: ['guardian-students'], queryFn: () => api<Student[]>('/api/v1/guardian/students')});
  return (
    <ScrollScreen safeTop={false} contentStyle={styles.noTopPadding}>
      <AppHeader mascot="profile" eyebrow="PORTAL WALI" title="Data ananda" subtitle="Hanya santri dengan relasi wali yang telah disetujui backend yang dapat diakses." />
      {students.isLoading ? <Loading label="Memuat data ananda..." mascot="profile" /> : null}
      {students.isError ? <ErrorState message={userMessage(students.error)} onRetry={() => students.refetch()} /> : null}
      {!students.isLoading && !students.isError && !students.data?.length ? <Empty icon="account" mascot="profile" text="Belum ada santri yang terhubung dengan akun wali ini." /> : null}
      {students.data?.map(student => (
        <Card key={student.id} onPress={() => navigation.navigate('GuardianStudent', {student})}>
          <View style={styles.row}>
            <AppIcon name="account" size={24} background />
            <View style={styles.copy}>
              <Text style={styles.name}>{student.full_name}</Text>
              <Muted>{student.student_no} · {student.class_name || 'Kelas belum diatur'}</Muted>
              <Text style={styles.program}>{student.program_name || 'Program belum diatur'}</Text>
            </View>
            <AppIcon name="chevronRight" size={20} color={colors.muted} />
          </View>
        </Card>
      ))}
    </ScrollScreen>
  );
}
const styles = StyleSheet.create({
  noTopPadding: {paddingTop: 0}, row: {flexDirection: 'row', alignItems: 'center', gap: space.md}, copy: {flex: 1},
  name: {...type.bodyStrong, color: colors.text, marginBottom: 3}, program: {...type.caption, color: colors.primary, marginTop: space.sm},
});
