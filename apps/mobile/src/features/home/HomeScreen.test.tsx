import React from 'react';
import {afterEach, beforeEach, describe, expect, it, jest} from '@jest/globals';
import {act, create, type ReactTestRenderer} from 'react-test-renderer';
import {AccessibilityInfo, Text} from 'react-native';
import type {Campaign, Kajian, Student, User} from '../../types/domain';
import HomeScreen from './HomeScreen';

type QueryResult<T> = {
  data?: T;
  isLoading: boolean;
  isError: boolean;
  error?: Error;
  refetch: jest.Mock;
};

let mockUser: User | null = null;
const mockQueries = new Map<string, QueryResult<unknown>>();

jest.mock('@tanstack/react-query', () => ({
  useQuery: ({queryKey}: {queryKey: unknown[]}) => mockQueries.get(String(queryKey[0])),
}));

jest.mock('../../api/client', () => ({
  api: jest.fn(),
  userMessage: (error: Error) => error.message,
}));

jest.mock('../../store/auth', () => ({
  useAuth: (selector: (state: {user: User | null}) => unknown) => selector({user: mockUser}),
}));

jest.mock('react-native-safe-area-context', () => ({
  SafeAreaView: ({children}: {children: React.ReactNode}) => children,
  useSafeAreaInsets: () => ({top: 0, right: 0, bottom: 0, left: 0}),
}));

const kajian: Kajian = {
  id: 'kajian-1',
  title: 'Kajian Akhlak',
  slug: 'kajian-akhlak',
  description: 'Belajar adab bersama.',
  speaker: 'Ustaz Demo',
  start_at: '2026-09-06T02:00:00Z',
  location: 'Aula Zabisa',
  status: 'PUBLISHED',
};

const campaign: Campaign = {
  id: 'campaign-1',
  name: 'Wakaf Al-Qur\'an',
  slug: 'wakaf-al-quran',
  description: 'Program wakaf.',
  category: 'Wakaf',
  target_amount: 10_000_000,
  collected_amount: 2_500_000,
  status: 'ACTIVE',
};

const student: Student = {
  id: 'student-1',
  student_no: 'S001',
  full_name: 'Santri Demo',
  class_name: 'Tahfidz A',
  program_name: 'Tahfidz',
  academic_year: '2026/2027',
  status: 'ACTIVE',
};

function result<T>(data?: T): QueryResult<T> {
  return {data, isLoading: false, isError: false, refetch: jest.fn()};
}

async function renderHome(navigate = jest.fn<(screen: string, params?: unknown) => void>()) {
  let component: ReactTestRenderer | undefined;
  await act(async () => {
    component = create(
      <HomeScreen
        navigation={{navigate} as never}
        route={{} as never}
      />,
    );
    await Promise.resolve();
  });
  return {component: component!, navigate};
}

describe('Nawasena HomeScreen', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    jest.spyOn(AccessibilityInfo, 'isReduceMotionEnabled').mockResolvedValue(true);
    mockUser = null;
    mockQueries.clear();
    mockQueries.set('kajian', result([kajian]));
    mockQueries.set('campaigns', result([campaign]));
    mockQueries.set('guardian-students', result<Student[]>([]));
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('renders public content and routes every service action', async () => {
    const {component, navigate} = await renderHome();
    const destinations = [
      ['Berbagi', 'Donasi'],
      ['Majelis Ilmu', 'Kajian'],
      ['Kabar Zabisa', 'ContentList'],
      ['Jejak Karya', 'ContentList'],
      ['Mengenal Kami', 'ContentList'],
      ['Momen Santri', 'ContentList'],
      ['Amanah Baru', 'Notifikasi'],
      ['Ruang Pribadi', 'Login'],
    ] as const;

    for (const [label, destination] of destinations) {
      act(() => component.root.findByProps({accessibilityLabel: label}).props.onPress());
      expect(navigate.mock.calls[navigate.mock.calls.length - 1][0]).toBe(destination);
    }

    expect(component.root.findAllByType(Text).some(node => node.props.children === 'Kajian Akhlak')).toBe(true);
    expect(component.root.findAllByType(Text).some(node => node.props.children === 'Wakaf Al-Qur\'an')).toBe(true);
  });

  it('shows the guardian greeting and opens the linked student', async () => {
    mockUser = {id: 'guardian-1', email: 'wali@example.test', name: 'Wali Demo', role: 'GUARDIAN', status: 'ACTIVE'};
    mockQueries.set('guardian-students', result([student]));
    const {component, navigate} = await renderHome();

    const studentActions = component.root.findAllByProps({accessibilityRole: 'button'}).filter(node =>
      typeof node.props.onPress === 'function' &&
      node.findAllByType(Text).some(text => text.props.children === 'Lihat ananda'),
    );
    expect(studentActions).toHaveLength(1);
    act(() => studentActions[0].props.onPress());
    expect(navigate).toHaveBeenCalledWith('GuardianStudent', {student});

    act(() => component.root.findByProps({accessibilityLabel: 'Ruang Pribadi'}).props.onPress());
    expect(navigate).toHaveBeenLastCalledWith('Akun');
  });

  it('exposes loading, error retry and empty states', async () => {
    const kajianRetry = jest.fn();
    const campaignRetry = jest.fn();
    mockQueries.set('kajian', {isLoading: false, isError: true, error: new Error('Kajian gagal'), refetch: kajianRetry});
    mockQueries.set('campaigns', {isLoading: false, isError: true, error: new Error('Donasi gagal'), refetch: campaignRetry});
    let rendered = (await renderHome()).component;

    const retries = rendered.root.findAllByProps({accessibilityLabel: 'Coba lagi'}).filter(node =>
      typeof node.props.onPress === 'function',
    );
    expect(retries).toHaveLength(2);
    for (const retry of retries) {
      act(() => retry.props.onPress());
    }
    expect(kajianRetry).toHaveBeenCalledTimes(1);
    expect(campaignRetry).toHaveBeenCalledTimes(1);

    act(() => rendered.unmount());
    mockQueries.set('kajian', {isLoading: true, isError: false, refetch: jest.fn()});
    mockQueries.set('campaigns', result<Kajian[]>([]));
    rendered = (await renderHome()).component;
    expect(rendered.root.findAllByType(Text).some(node => node.props.children === 'Memuat kajian terbaru...')).toBe(true);

    act(() => rendered.unmount());
    mockQueries.set('kajian', result<Kajian[]>([]));
    mockQueries.set('campaigns', result<Campaign[]>([]));
    rendered = (await renderHome()).component;
    const copy = rendered.root.findAllByType(Text).map(node => node.props.children);
    expect(copy).toContain('Belum ada kajian yang dipublikasikan.');
    expect(copy).toContain('Belum ada campaign donasi aktif.');
  });
});
