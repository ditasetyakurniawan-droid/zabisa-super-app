import React from 'react';
import {afterEach, describe, expect, it, jest} from '@jest/globals';
import {act, create, type ReactTestRenderer} from 'react-test-renderer';
import {AccessibilityInfo, Image, Text} from 'react-native';
import {Loading, PremiumServiceCard} from './UI';
import {Mascot} from './Mascot';
import {StartupLoading} from './StartupLoading';

jest.mock('react-native-safe-area-context', () => ({
  SafeAreaView: ({children}: {children: React.ReactNode}) => children,
  useSafeAreaInsets: () => ({top: 0, right: 0, bottom: 0, left: 0}),
}));

afterEach(() => {
  jest.restoreAllMocks();
});

describe('premium mobile presentation', () => {
  it('keeps service action semantics while honoring reduced motion', async () => {
    jest.spyOn(AccessibilityInfo, 'isReduceMotionEnabled').mockResolvedValue(true);
    const onPress = jest.fn();
    let component: ReactTestRenderer | undefined;

    await act(async () => {
      component = create(<PremiumServiceCard icon="donation" label="Berbagi" subtitle="Donasi" onPress={onPress} />);
      await Promise.resolve();
    });

    const control = component!.root.findByProps({accessibilityLabel: 'Berbagi'});
    expect(control.props.accessibilityRole).toBe('button');
    expect(control.props.accessibilityHint).toBe('Donasi');
    act(() => control.props.onPressIn());
    act(() => control.props.onPress());
    act(() => control.props.onPressOut());
    expect(onPress).toHaveBeenCalledTimes(1);
    act(() => component!.unmount());
  });

  it('renders contextual male and female mascot variants as local images', () => {
    let component: ReactTestRenderer | undefined;
    act(() => {
      component = create(
        <>
          <Mascot variant="tahfidz" />
          <Mascot variant="academic" />
        </>,
      );
    });

    expect(component!.root.findByProps({accessibilityLabel: 'Mascot santri tahfidz'})).toBeDefined();
    expect(component!.root.findByProps({accessibilityLabel: 'Mascot santri akademik'})).toBeDefined();
    expect(component!.root.findAllByType(Image)).toHaveLength(4);
    act(() => component!.unmount());
  });

  it('renders a premium bootstrap without fake progress while preserving real in-page loading', async () => {
    jest.spyOn(AccessibilityInfo, 'isReduceMotionEnabled').mockResolvedValue(true);
    let component: ReactTestRenderer | undefined;

    await act(async () => {
      component = create(
        <>
          <StartupLoading />
          <Loading label="Memuat kajian terbaru..." />
        </>,
      );
      await Promise.resolve();
    });

    const copy = component!.root.findAllByType(Text).map(node => node.props.children);
    expect(copy).toContain('Zabisa');
    expect(copy).toContain('Belajar Al-Qur’an, tumbuh dalam adab.');
    expect(copy).toContain('Memuat kajian terbaru...');
    expect(copy).toContain('“Sebaik-baik kalian adalah yang belajar Al-Qur’an dan mengajarkannya.”');
    expect(copy).toContain('HR. Bukhari');
    expect(copy).not.toContain('Menyiapkan ruang belajar…');
    expect(copy).toContain('Pendidikan • Adab • Al-Qur’an');
    expect(copy).not.toContain('Kajian publik');
    expect(copy).not.toContain('Donasi amanah');
    expect(copy).not.toContain('Portal wali');
    const progressbars = component!.root.findAllByProps({accessibilityRole: 'progressbar'});
    expect(progressbars.some(node => node.props.accessibilityLabel === 'Menyiapkan Zabisa')).toBe(false);
    expect(progressbars.some(node => node.props.accessibilityLabel === 'Memuat kajian terbaru...')).toBe(true);
    expect(component!.root.findAllByType(Image).length).toBeGreaterThanOrEqual(3);
    act(() => component!.unmount());
  });
});
