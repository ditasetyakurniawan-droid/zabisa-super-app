import React from 'react';
import {afterEach, beforeEach, describe, expect, it, jest} from '@jest/globals';
import {act, create, type ReactTestInstance, type ReactTestRenderer} from 'react-test-renderer';
import {AccessibilityInfo, Linking, Text} from 'react-native';
import type {Attendance, Campaign, CampaignUpdate, ContentItem, DonationHistoryItem, Grade, Kajian, NotificationItem, PaymentMethod, Student, StudentReport, TahfidzEntry, User} from '../types/domain';
import DonationScreen from './donation/DonationScreen';
import CampaignDetailScreen from './donation/CampaignDetailScreen';
import DonationCheckoutScreen from './donation/DonationCheckoutScreen';
import KajianScreen from './kajian/KajianScreen';
import KajianDetailScreen from './kajian/KajianDetailScreen';
import ContentListScreen from './content/ContentListScreen';
import ContentDetailScreen from './content/ContentDetailScreen';
import GuardianStudentScreen from './guardian/GuardianStudentScreen';
import NotificationsScreen from './notifications/NotificationsScreen';
import GuardianOverviewScreen from './guardian/GuardianOverviewScreen';
import AccountScreen from './account/AccountScreen';
import LoginScreen from './auth/LoginScreen';

type QueryResult = {
  data?: unknown;
  isLoading: boolean;
  isError: boolean;
  error?: Error;
  refetch: ReturnType<typeof jest.fn>;
};

let mockUser: User | null = null;
let mockBusy = false;
const mockQueries = new Map<string, QueryResult>();
const mockMutate = jest.fn();
const mockInvalidateQueries = jest.fn();
const mockLogin = jest.fn();
const mockLogout = jest.fn();
let mutationSuccess: ((data: unknown) => void) | undefined;

jest.mock('@tanstack/react-query', () => ({
  useQuery: ({queryKey}: {queryKey: unknown[]}) => mockQueries.get(String(queryKey[0])) ?? {
    data: undefined,
    isLoading: false,
    isError: false,
    refetch: jest.fn(),
  },
  useMutation: ({onSuccess}: {onSuccess?: (data: unknown) => void}) => {
    mutationSuccess = onSuccess;
    return {mutate: mockMutate, isPending: false, error: null};
  },
  useQueryClient: () => ({invalidateQueries: mockInvalidateQueries}),
}));

jest.mock('../api/client', () => ({
  api: jest.fn(),
  userMessage: (error: Error) => error.message,
}));

jest.mock('../store/auth', () => ({
  useAuth: (selector: (state: {user: User | null; busy: boolean; login: typeof mockLogin; logout: typeof mockLogout}) => unknown) => selector({user: mockUser, busy: mockBusy, login: mockLogin, logout: mockLogout}),
}));

jest.mock('react-native-safe-area-context', () => ({
  SafeAreaView: ({children}: {children: React.ReactNode}) => children,
  useSafeAreaInsets: () => ({top: 0, right: 0, bottom: 0, left: 0}),
}));

const campaign: Campaign = {
  id: 'campaign-1', name: 'Wakaf Al-Qur\'an', slug: 'wakaf-al-quran',
  description: 'Program wakaf mushaf.', category: 'Wakaf',
  target_amount: 10_000_000, collected_amount: 2_500_000, status: 'ACTIVE',
};

const kajian: Kajian = {
  id: 'kajian-1', title: 'Kajian Akhlak', slug: 'kajian-akhlak',
  description: 'Belajar adab bersama.', speaker: 'Ustaz Demo',
  start_at: '2026-09-06T02:00:00Z', location: 'Aula Zabisa',
  map_url: 'https://maps.example.test/zabisa', live_url: 'https://video.example.test/zabisa', status: 'PUBLISHED',
};

function query(data?: unknown): QueryResult {
  return {data, isLoading: false, isError: false, refetch: jest.fn()};
}

async function render(element: React.ReactElement) {
  let component: ReactTestRenderer | undefined;
  await act(async () => {
    component = create(element);
    await Promise.resolve();
  });
  return component!;
}

async function press(node: ReactTestInstance) {
  const onPress: unknown = node.props.onPress;
  if (typeof onPress !== 'function') {
    throw new Error('Expected a pressable test node');
  }
  await act(async () => {
    onPress();
    await Promise.resolve();
  });
}

async function unmount(component: ReactTestRenderer) {
  await act(async () => {
    component.unmount();
    await Promise.resolve();
  });
}

describe('Nawasena service screens', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    jest.spyOn(AccessibilityInfo, 'isReduceMotionEnabled').mockResolvedValue(true);
    mockUser = {id: 'guardian-1', email: 'wali@example.test', name: 'Wali Demo', role: 'GUARDIAN', status: 'ACTIVE'};
    mockBusy = false;
    mockQueries.clear();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('renders donation campaign/history and opens its detail', async () => {
    const history: DonationHistoryItem = {id: 'donation-1', campaign_name: campaign.name, amount: 100_000, status: 'VERIFIED', created_at: '2026-09-05T00:00:00Z'};
    mockQueries.set('campaigns', query([campaign]));
    mockQueries.set('donation-history', query([history]));
    const navigate = jest.fn<(screen: string, params?: unknown) => void>();
    const component = await render(<DonationScreen navigation={{navigate} as never} route={{} as never} />);

    const campaignButton = component.root.findAllByProps({accessibilityRole: 'button'})
      .find(node => node.findAllByType(Text).some(text => text.props.children === campaign.name))!;
    await press(campaignButton);
    expect(navigate).toHaveBeenCalledWith('CampaignDetail', {campaign});
    await unmount(component);
  });

  it('renders campaign detail and starts checkout', async () => {
    const update: CampaignUpdate = {id: 'update-1', title: 'Mushaf tiba', body: 'Distribusi dimulai.', created_at: '2026-09-05T00:00:00Z'};
    mockQueries.set('campaign-updates', query([update]));
    const navigate = jest.fn<(screen: string, params?: unknown) => void>();
    const component = await render(
      <CampaignDetailScreen navigation={{navigate} as never} route={{params: {campaign}} as never} />,
    );

    await press(component.root.findByProps({accessibilityLabel: 'Donasi sekarang'}));
    expect(navigate).toHaveBeenCalledWith('DonationCheckout', {campaign});
    await unmount(component);
  });

  it('renders checkout presets, payment method and submit control', async () => {
    const method: PaymentMethod = {
      method_code: 'BRIVA', display_name: 'BRIVA', bank_name: 'BRI',
      account_number: '1234567890', account_holder: 'Yayasan Zabisa', instructions: 'Transfer sesuai nominal.',
    };
    mockQueries.set('payment-methods', query([method]));
    const component = await render(
      <DonationCheckoutScreen navigation={{} as never} route={{params: {campaign}} as never} />,
    );

    await press(component.root.findByProps({accessibilityLabel: 'Rp 50.000'}));
    await press(component.root.findByProps({accessibilityLabel: 'Tunaikan niat baik'}));
    expect(mockMutate).toHaveBeenCalledTimes(1);
    await act(async () => {
      mutationSuccess?.({id: 'donation-1', status: 'WAITING_PAYMENT'});
      await Promise.resolve();
    });
    expect(component.root.findAllByType(Text).some(text => text.props.children === 'Transaksi berhasil dibuat')).toBe(true);
    await unmount(component);
  });

  it('renders kajian list/detail and opens published external links', async () => {
    mockQueries.set('kajian', query([kajian]));
    const navigate = jest.fn<(screen: string, params?: unknown) => void>();
    const list = await render(<KajianScreen navigation={{navigate} as never} route={{} as never} />);
    const kajianButton = list.root.findAllByProps({accessibilityRole: 'button'})
      .find(node => node.findAllByType(Text).some(text => text.props.children === kajian.title))!;
    await press(kajianButton);
    expect(navigate).toHaveBeenCalledWith('KajianDetail', {kajian});

    const openURL = jest.spyOn(Linking, 'openURL').mockResolvedValue(undefined);
    const detail = await render(
      <KajianDetailScreen navigation={{} as never} route={{params: {kajian}} as never} />,
    );
    await press(detail.root.findByProps({accessibilityLabel: 'Buka peta'}));
    await press(detail.root.findByProps({accessibilityLabel: 'Buka live stream'}));
    expect(openURL).toHaveBeenNthCalledWith(1, kajian.map_url);
    expect(openURL).toHaveBeenNthCalledWith(2, kajian.live_url);
    await unmount(list);
    await unmount(detail);
  });

  it('renders public content variants and preserves ContentDetail navigation', async () => {
    const items: ContentItem[] = [
      {id: 'news-1', type: 'news', title: 'Kabar Zabisa', slug: 'kabar-zabisa', summary: 'Kabar terbaru.', body: 'Isi berita.'},
      {id: 'program-1', type: 'programs', title: 'Program Santri', slug: 'program-santri', summary: 'Program publik.', body: 'Isi program.'},
      {id: 'gallery-1', type: 'gallery', title: 'Galeri Kegiatan', slug: 'galeri-kegiatan', summary: 'Dokumentasi.', body: 'Isi galeri.'},
      {id: 'profile-1', type: 'profile', title: 'Tentang Zabisa', slug: 'tentang-zabisa', summary: 'Profil publik.', body: 'Isi profil.'},
    ];

    for (const item of items) {
      mockQueries.set('content', query([item]));
      const navigate = jest.fn<(screen: string, params?: unknown) => void>();
      const list = await render(
        <ContentListScreen
          navigation={{navigate} as never}
          route={{params: {type: item.type, title: item.title}} as never}
        />,
      );
      const itemButton = list.root.findAllByProps({accessibilityRole: 'button'})
        .find(node => node.findAllByType(Text).some(text => text.props.children === item.title))!;
      await press(itemButton);
      expect(navigate).toHaveBeenCalledWith('ContentDetail', {id: item.id, title: item.title});
      await unmount(list);

      mockQueries.set('content-detail', query(item));
      const detail = await render(
        <ContentDetailScreen navigation={{} as never} route={{params: {id: item.id, title: item.title}} as never} />,
      );
      expect(detail.root.findAllByType(Text).some(text => text.props.children === item.body)).toBe(true);
      await unmount(detail);
    }
  });

  it('renders public content loading, empty, error, retry and missing-detail states', async () => {
    const refetch = jest.fn();
    mockQueries.set('content', {isLoading: true, isError: false, refetch});
    let component = await render(
      <ContentListScreen navigation={{navigate: jest.fn()} as never} route={{params: {type: 'news', title: 'Berita'}} as never} />,
    );
    expect(component.root.findAllByType(Text).some(text => text.props.children === 'Memuat berita...')).toBe(true);
    await unmount(component);

    mockQueries.set('content', query([]));
    component = await render(
      <ContentListScreen navigation={{navigate: jest.fn()} as never} route={{params: {type: 'news', title: 'Berita'}} as never} />,
    );
    expect(component.root.findAllByType(Text).some(text => text.props.children === 'Belum ada berita yang dipublikasikan.')).toBe(true);
    await unmount(component);

    mockQueries.set('content', {isLoading: false, isError: true, error: new Error('Konten gagal dimuat'), refetch});
    component = await render(
      <ContentListScreen navigation={{navigate: jest.fn()} as never} route={{params: {type: 'news', title: 'Berita'}} as never} />,
    );
    await press(component.root.findByProps({accessibilityLabel: 'Coba lagi'}));
    expect(refetch).toHaveBeenCalledTimes(1);
    await unmount(component);

    mockQueries.set('content-detail', {isLoading: true, isError: false, refetch});
    component = await render(
      <ContentDetailScreen navigation={{} as never} route={{params: {id: 'news-1', title: 'Kabar Zabisa'}} as never} />,
    );
    expect(component.root.findAllByType(Text).some(text => text.props.children === 'Memuat kabar zabisa...')).toBe(true);
    await unmount(component);

    mockQueries.set('content-detail', {isLoading: false, isError: true, error: new Error('Detail gagal dimuat'), refetch});
    component = await render(
      <ContentDetailScreen navigation={{} as never} route={{params: {id: 'news-1', title: 'Kabar Zabisa'}} as never} />,
    );
    await press(component.root.findByProps({accessibilityLabel: 'Coba lagi'}));
    expect(refetch).toHaveBeenCalledTimes(2);
    await unmount(component);

    mockQueries.set('content-detail', query(undefined));
    component = await render(
      <ContentDetailScreen navigation={{} as never} route={{params: {id: 'missing', title: 'Informasi'}} as never} />,
    );
    expect(component.root.findAllByType(Text).some(text => text.props.children === 'Konten tidak ditemukan.')).toBe(true);
    await unmount(component);
  });

  it('renders complete guardian learning progress and attendance tones', async () => {
    const student: Student = {id: 'student-1', student_no: 'S001', full_name: 'Ahmad', class_name: '7A', program_name: 'Tahfidz', academic_year: '2026/2027', status: 'ACTIVE'};
    const tahfidz: TahfidzEntry = {id: 'entry-1', surah: 'Al-Fatihah', ayah_start: 1, ayah_end: 7, activity_type: 'MEMORIZATION', date: '2026-09-05', teacher_note: 'Baik'};
    const grade: Grade = {id: 'grade-1', subject_name: 'Fiqih', score: 90, assessment_type: 'EXAM', semester: 1, teacher_note: 'Pertahankan'};
    const attendance: Attendance[] = [{date: '2026-09-05', status: 'PRESENT', note: 'Tepat waktu'}, {date: '2026-09-06', status: 'ABSENT'}];
    const report: StudentReport = {id: 'report-1', report_type: 'ACADEMIC', academic_year: '2026/2027', semester: 1, status: 'PUBLISHED'};
    mockQueries.set('student-tahfidz', query([tahfidz]));
    mockQueries.set('student-grades', query([grade]));
    mockQueries.set('student-attendance', query(attendance));
    mockQueries.set('student-reports', query([report]));

    const component = await render(<GuardianStudentScreen navigation={{} as never} route={{params: {student}} as never} />);
    const text = component.root.findAllByType(Text).map(node => node.props.children);
    expect(text).toContain('Ahmad');
    expect(text).toContain('Al-Fatihah');
    expect(text).toContain('Fiqih');
    await unmount(component);
  });

  it('covers guardian empty and dependency-error states', async () => {
    const student: Student = {id: 'student-1', student_no: 'S001', full_name: 'Ahmad', class_name: '', program_name: '', academic_year: '', status: 'ACTIVE'};
    mockQueries.set('student-tahfidz', query([]));
    mockQueries.set('student-grades', query([]));
    mockQueries.set('student-attendance', query([]));
    mockQueries.set('student-reports', query([]));
    let component = await render(<GuardianStudentScreen navigation={{} as never} route={{params: {student}} as never} />);
    expect(component.root.findAllByType(Text).some(text => text.props.children === 'Belum ada setoran tahfidz.')).toBe(true);
    await unmount(component);

    const refetch = jest.fn();
    const failure = {isLoading: false, isError: true, error: new Error('Dependency gagal'), refetch};
    mockQueries.set('student-tahfidz', failure);
    mockQueries.set('student-grades', failure);
    mockQueries.set('student-attendance', failure);
    mockQueries.set('student-reports', failure);
    component = await render(<GuardianStudentScreen navigation={{} as never} route={{params: {student}} as never} />);
    const retryButtons = component.root
      .findAllByProps({accessibilityLabel: 'Coba lagi'})
      .filter(button => typeof button.props.onPress === 'function');
    for (const button of retryButtons) await press(button);
    expect(refetch).toHaveBeenCalledTimes(4);
    await unmount(component);
  });

  it('renders notification inbox and opens a guardian deep link', async () => {
    const student: Student = {id: 'student-1', student_no: 'S001', full_name: 'Ahmad', class_name: '7A', program_name: 'Tahfidz', academic_year: '2026/2027', status: 'ACTIVE'};
    const notification: NotificationItem = {id: 'notification-1', type: 'TAHFIDZ', title: 'Setoran baru', message: 'Setoran Ahmad tersedia.', deep_link: 'zabisa://guardian/students/student-1/tahfidz/entry-1', read: false, created_at: '2026-09-06T00:00:00Z'};
    mockQueries.set('notifications', query([notification]));
    mockQueries.set('guardian-students', query([student]));
    const navigate = jest.fn<(screen: string, params?: unknown) => void>();
    const component = await render(<NotificationsScreen navigation={{navigate} as never} route={{} as never} />);
    const notificationButton = component.root.findAllByProps({accessibilityRole: 'button'})
      .find(node => node.findAllByType(Text).some(text => text.props.children === notification.title));
    expect(notificationButton).toBeDefined();
    await press(notificationButton!);
    expect(navigate).toHaveBeenCalledWith('GuardianStudent', {student});
    expect(mockMutate).toHaveBeenCalledWith(notification.id);
    await unmount(component);
  });

  it('covers notification guest, loading, error and kajian navigation states', async () => {
    const navigate = jest.fn<(screen: string, params?: unknown) => void>();
    mockUser = null;
    let component = await render(<NotificationsScreen navigation={{navigate} as never} route={{} as never} />);
    expect(component.root.findAllByType(Text).some(text => text.props.children === 'Login melalui menu Akun untuk melihat notifikasi pribadi.')).toBe(true);
    await unmount(component);

    mockUser = {id: 'user-1', email: 'user@example.test', name: 'User', role: 'DONOR', status: 'ACTIVE'};
    mockQueries.set('notifications', {isLoading: true, isError: false, refetch: jest.fn()});
    component = await render(<NotificationsScreen navigation={{navigate} as never} route={{} as never} />);
    expect(component.root.findAllByType(Text).some(text => text.props.children === 'Memuat notifikasi...')).toBe(true);
    await unmount(component);

    const refetch = jest.fn();
    mockQueries.set('notifications', {isLoading: false, isError: true, error: new Error('Inbox gagal'), refetch});
    component = await render(<NotificationsScreen navigation={{navigate} as never} route={{} as never} />);
    await press(component.root.findByProps({accessibilityLabel: 'Coba lagi'}));
    expect(refetch).toHaveBeenCalledTimes(1);
    await unmount(component);

    const kajianNotification: NotificationItem = {id: 'notification-2', type: 'KAJIAN', title: 'Kajian baru', message: 'Kajian tersedia.', deep_link: 'zabisa://kajian/kajian-1', read: true, created_at: '2026-09-06T00:00:00Z'};
    mockQueries.set('notifications', query([kajianNotification]));
    component = await render(<NotificationsScreen navigation={{navigate} as never} route={{} as never} />);
    const kajianButton = component.root.findAllByProps({accessibilityRole: 'button'})
      .find(node => node.findAllByType(Text).some(text => text.props.children === kajianNotification.title));
    await press(kajianButton!);
    expect(navigate).toHaveBeenCalledWith('Kajian');
    await unmount(component);
  });

  it('covers guardian overview, guest account and authenticated account actions', async () => {
    const student: Student = {id: 'student-1', student_no: 'S001', full_name: 'Ahmad', class_name: '7A', program_name: 'Tahfidz', academic_year: '2026/2027', status: 'ACTIVE'};
    mockQueries.set('guardian-students', query([student]));
    const navigate = jest.fn<(screen: string, params?: unknown) => void>();
    let component = await render(<GuardianOverviewScreen navigation={{navigate} as never} route={{} as never} />);
    const studentButton = component.root.findAllByProps({accessibilityRole: 'button'})
      .find(node => node.findAllByType(Text).some(text => text.props.children === student.full_name));
    await press(studentButton!);
    expect(navigate).toHaveBeenCalledWith('GuardianStudent', {student});
    await unmount(component);

    mockUser = null;
    component = await render(<AccountScreen navigation={{navigate} as never} route={{} as never} />);
    await press(component.root.findByProps({accessibilityLabel: 'Masuk'}));
    expect(navigate).toHaveBeenCalledWith('Login');
    await unmount(component);

    mockUser = {id: 'guardian-1', email: 'wali@example.test', name: 'Wali Demo', role: 'GUARDIAN', status: 'ACTIVE'};
    component = await render(<AccountScreen navigation={{navigate} as never} route={{} as never} />);
    await press(component.root.findByProps({accessibilityLabel: 'Buka data ananda'}));
    await press(component.root.findByProps({accessibilityLabel: 'Keluar dari akun'}));
    expect(mockLogout).toHaveBeenCalledTimes(1);
    await unmount(component);
  });

  it('covers successful login and authenticated redirect', async () => {
    mockUser = null;
    const reset = jest.fn();
    let component = await render(<LoginScreen navigation={{reset} as never} route={{} as never} />);
    await press(component.root.findByProps({accessibilityLabel: 'Masuk'}));
    expect(mockLogin).toHaveBeenCalled();
    await unmount(component);

    mockUser = {id: 'guardian-1', email: 'wali@example.test', name: 'Wali Demo', role: 'GUARDIAN', status: 'ACTIVE'};
    component = await render(<LoginScreen navigation={{reset} as never} route={{} as never} />);
    expect(reset).toHaveBeenCalledWith({index: 0, routes: [{name: 'Main', params: {screen: 'Akun'}}]});
    await unmount(component);
  });

});
