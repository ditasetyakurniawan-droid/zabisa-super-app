import React from 'react';
import {afterEach, beforeEach, describe, expect, it, jest} from '@jest/globals';
import {act, create, type ReactTestRenderer} from 'react-test-renderer';
import {AccessibilityInfo, Linking, Text} from 'react-native';
import type {Campaign, CampaignUpdate, DonationHistoryItem, Kajian, PaymentMethod, User} from '../types/domain';
import DonationScreen from './donation/DonationScreen';
import CampaignDetailScreen from './donation/CampaignDetailScreen';
import DonationCheckoutScreen from './donation/DonationCheckoutScreen';
import KajianScreen from './kajian/KajianScreen';
import KajianDetailScreen from './kajian/KajianDetailScreen';

type QueryResult = {
  data?: unknown;
  isLoading: boolean;
  isError: boolean;
  error?: Error;
  refetch: ReturnType<typeof jest.fn>;
};

let mockUser: User | null = null;
const mockQueries = new Map<string, QueryResult>();
const mockMutate = jest.fn();

jest.mock('@tanstack/react-query', () => ({
  useQuery: ({queryKey}: {queryKey: unknown[]}) => mockQueries.get(String(queryKey[0])),
  useMutation: () => ({mutate: mockMutate, isPending: false, error: null}),
}));

jest.mock('../api/client', () => ({
  api: jest.fn(),
  userMessage: (error: Error) => error.message,
}));

jest.mock('../store/auth', () => ({
  useAuth: (selector: (state: {user: User | null}) => unknown) => selector({user: mockUser}),
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

describe('Nawasena service screens', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    jest.spyOn(AccessibilityInfo, 'isReduceMotionEnabled').mockResolvedValue(true);
    mockUser = {id: 'guardian-1', email: 'wali@example.test', name: 'Wali Demo', role: 'GUARDIAN', status: 'ACTIVE'};
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
    act(() => campaignButton.props.onPress());
    expect(navigate).toHaveBeenCalledWith('CampaignDetail', {campaign});
  });

  it('renders campaign detail and starts checkout', async () => {
    const update: CampaignUpdate = {id: 'update-1', title: 'Mushaf tiba', body: 'Distribusi dimulai.', created_at: '2026-09-05T00:00:00Z'};
    mockQueries.set('campaign-updates', query([update]));
    const navigate = jest.fn<(screen: string, params?: unknown) => void>();
    const component = await render(
      <CampaignDetailScreen navigation={{navigate} as never} route={{params: {campaign}} as never} />,
    );

    act(() => component.root.findByProps({accessibilityLabel: 'Donasi sekarang'}).props.onPress());
    expect(navigate).toHaveBeenCalledWith('DonationCheckout', {campaign});
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

    act(() => component.root.findByProps({accessibilityLabel: 'Rp 50.000'}).props.onPress());
    act(() => component.root.findByProps({accessibilityLabel: 'Tunaikan niat baik'}).props.onPress());
    expect(mockMutate).toHaveBeenCalledTimes(1);
  });

  it('renders kajian list/detail and opens published external links', async () => {
    mockQueries.set('kajian', query([kajian]));
    const navigate = jest.fn<(screen: string, params?: unknown) => void>();
    const list = await render(<KajianScreen navigation={{navigate} as never} route={{} as never} />);
    const kajianButton = list.root.findAllByProps({accessibilityRole: 'button'})
      .find(node => node.findAllByType(Text).some(text => text.props.children === kajian.title))!;
    act(() => kajianButton.props.onPress());
    expect(navigate).toHaveBeenCalledWith('KajianDetail', {kajian});

    const openURL = jest.spyOn(Linking, 'openURL').mockResolvedValue(undefined);
    const detail = await render(
      <KajianDetailScreen navigation={{} as never} route={{params: {kajian}} as never} />,
    );
    act(() => detail.root.findByProps({accessibilityLabel: 'Buka peta'}).props.onPress());
    act(() => detail.root.findByProps({accessibilityLabel: 'Buka live stream'}).props.onPress());
    expect(openURL).toHaveBeenNthCalledWith(1, kajian.map_url);
    expect(openURL).toHaveBeenNthCalledWith(2, kajian.live_url);
  });
});
