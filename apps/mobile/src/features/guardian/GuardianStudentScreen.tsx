import React from 'react';
import {StyleSheet, Text, View} from 'react-native';
import {useQuery} from '@tanstack/react-query';
import {api, userMessage} from '../../api/client';
import {AppHeader, Card, Empty, ErrorState, Loading, Muted, Pill, ScrollScreen, SectionTitle, StatCard} from '../../components/UI';
import {colors, space, type} from '../../theme/tokens';
import type {Attendance, Grade, StudentReport, TahfidzEntry} from '../../types/domain';
import {
  formatActivityType,
  formatAttendanceStatus,
  formatDateID,
  formatDevelopmentNote,
  formatReportStatus,
  formatAssessmentType,
  formatReportType,
} from '../../utils/format';
import type {RootStackScreenProps} from '../../navigation/types';

function attendanceValue(statuses?: Attendance[]) {
  if (!statuses) return '–';
  if (statuses.length === 0) return 0;
  const present = statuses.filter(item => item.status === 'PRESENT').length;
  return `${present}/${statuses.length}`;
}

function attendanceTone(status: string) {
  if (status === 'PRESENT') return 'success' as const;
  if (status === 'ABSENT') return 'danger' as const;
  return 'warning' as const;
}

export default function GuardianStudentScreen({route}: RootStackScreenProps<'GuardianStudent'>) {
  const student = route.params.student;
  const tahfidz = useQuery({queryKey: ['student-tahfidz', student.id], queryFn: () => api<TahfidzEntry[]>(`/api/v1/tahfidz/students/${student.id}/entries`)});
  const grades = useQuery({queryKey: ['student-grades', student.id], queryFn: () => api<Grade[]>(`/api/v1/students/${student.id}/grades`)});
  const attendance = useQuery({queryKey: ['student-attendance', student.id], queryFn: () => api<Attendance[]>(`/api/v1/guardian/students/${student.id}/attendance`)});
  const reports = useQuery({queryKey: ['student-reports', student.id], queryFn: () => api<StudentReport[]>(`/api/v1/students/${student.id}/reports`)});
  const attendanceSummary = attendanceValue(attendance.data);

  return (
    <ScrollScreen safeTop={false} contentStyle={styles.noTopPadding}>
      <AppHeader mascot="tahfidz" eyebrow="TAHFIDZ & AKADEMIK" title={student.full_name} subtitle={`${student.student_no} · ${student.class_name || '-'} · ${student.academic_year || '-'}`} />
      <View style={styles.stats}>
        <StatCard icon="tahfidz" value={tahfidz.data?.length ?? '–'} label="Setoran" />
        <StatCard icon="grade" value={grades.data?.length ?? '–'} label="Nilai" />
        <StatCard icon="attendance" value={attendanceSummary} label="Hadir" />
      </View>

      <SectionTitle>Tahfidz terbaru</SectionTitle>
      {tahfidz.isLoading ? <Loading label="Memuat tahfidz..." mascot="tahfidz" /> : null}
      {tahfidz.isError ? <ErrorState message={userMessage(tahfidz.error)} onRetry={() => tahfidz.refetch()} /> : null}
      {!tahfidz.isLoading && !tahfidz.isError && !tahfidz.data?.length ? <Empty icon="tahfidz" mascot="tahfidz" text="Belum ada setoran tahfidz." /> : null}
      {tahfidz.data?.slice(0, 8).map(entry => (
        <Card key={entry.id}>
          <View style={styles.rowBetween}><Text style={styles.itemTitle}>{entry.surah}</Text><Pill tone="primary" text={formatActivityType(entry.activity_type)} /></View>
          <Text style={styles.detail}>Ayat {entry.ayah_start}–{entry.ayah_end}</Text>
          <Muted>{formatDateID(entry.activity_date || entry.date)}</Muted>
          {entry.teacher_note ? <Text style={styles.note}>{formatDevelopmentNote(entry.teacher_note)}</Text> : null}
        </Card>
      ))}

      <SectionTitle>Nilai terbaru</SectionTitle>
      {grades.isLoading ? <Loading label="Memuat nilai..." mascot="academic" /> : null}
      {grades.isError ? <ErrorState message={userMessage(grades.error)} onRetry={() => grades.refetch()} /> : null}
      {!grades.isLoading && !grades.isError && !grades.data?.length ? <Empty icon="grade" mascot="academic" text="Belum ada nilai yang dipublikasikan." /> : null}
      {grades.data?.slice(0, 8).map(grade => (
        <Card key={grade.id}>
          <View style={styles.rowBetween}><Text style={styles.itemTitle}>{grade.subject_name}</Text><Text style={styles.score}>{grade.score ?? grade.grade ?? '-'}</Text></View>
          <Muted>{formatAssessmentType(grade.assessment_type)} · Semester {grade.semester ?? '-'}</Muted>
          {grade.teacher_note ? <Text style={styles.note}>{formatDevelopmentNote(grade.teacher_note)}</Text> : null}
        </Card>
      ))}

      <SectionTitle>Kehadiran</SectionTitle>
      {attendance.isLoading ? <Loading label="Memuat kehadiran..." mascot="attendance" /> : null}
      {attendance.isError ? <ErrorState message={userMessage(attendance.error)} onRetry={() => attendance.refetch()} /> : null}
      {!attendance.isLoading && !attendance.isError && !attendance.data?.length ? <Empty icon="attendance" mascot="attendance" text="Belum ada data kehadiran." /> : null}
      {attendance.data?.slice(0, 10).map(item => (
        <Card key={`${item.date}-${item.status}-${item.note ?? ''}`}>
          <View style={styles.rowBetween}>
            <Text style={styles.itemTitle}>{formatDateID(item.date)}</Text>
            <Pill tone={attendanceTone(item.status)} text={formatAttendanceStatus(item.status)} />
          </View>
          {item.note ? <Muted>{formatDevelopmentNote(item.note)}</Muted> : null}
        </Card>
      ))}

      <SectionTitle>Report perkembangan</SectionTitle>
      {reports.isLoading ? <Loading label="Memuat report..." mascot="academic" /> : null}
      {reports.isError ? <ErrorState message={userMessage(reports.error)} onRetry={() => reports.refetch()} /> : null}
      {!reports.isLoading && !reports.isError && !reports.data?.length ? <Empty icon="info" mascot="academic" text="Belum ada report yang dipublikasikan." /> : null}
      {reports.data?.map(report => (
        <Card key={report.id}>
          <View style={styles.rowBetween}><Text style={styles.itemTitle}>{formatReportType(report.report_type)}</Text><Pill tone="primary" text={formatReportStatus(report.status)} /></View>
          <Muted>{report.academic_year} · Semester {report.semester}</Muted>
        </Card>
      ))}
    </ScrollScreen>
  );
}

const styles = StyleSheet.create({
  noTopPadding: {paddingTop: 0},
  stats: {flexDirection: 'row', gap: space.sm, marginTop: space.sm},
  rowBetween: {flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', gap: space.md},
  itemTitle: {...type.bodyStrong, color: colors.text, flexShrink: 1},
  detail: {...type.body, color: colors.textSoft, marginTop: space.xs, marginBottom: 2},
  note: {...type.body, color: colors.text, marginTop: space.sm, paddingTop: space.sm, borderTopWidth: 1, borderTopColor: colors.line},
  score: {fontSize: 22, lineHeight: 26, fontWeight: '900', color: colors.primary},
});
