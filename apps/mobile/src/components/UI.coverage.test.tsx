import React from 'react';
import {afterEach, describe, expect, it, jest} from '@jest/globals';
import {act, create, type ReactTestRenderer} from 'react-test-renderer';
import {AccessibilityInfo, Text, TextInput, View} from 'react-native';
import {
  AppHeader,
  Body,
  Button,
  Card,
  DetailHeader,
  DisplayTitle,
  Empty,
  ErrorState,
  HeroCard,
  IconTile,
  IslamicOrnament,
  Loading,
  Muted,
  Pill,
  Screen,
  ScrollScreen,
  SectionTitle,
  StatCard,
  TextButton,
  TextField,
  Title,
} from './UI';

jest.mock('react-native-safe-area-context', () => ({
  SafeAreaView: ({children}: {children: React.ReactNode}) => children,
  useSafeAreaInsets: () => ({top: 0, right: 0, bottom: 0, left: 0}),
}));

afterEach(() => {
  jest.restoreAllMocks();
});

describe('Nawasena shared UI', () => {
  it('renders layout, headings, ornament and semantic copy variants', async () => {
    jest.spyOn(AccessibilityInfo, 'isReduceMotionEnabled').mockResolvedValue(true);
    let component: ReactTestRenderer | undefined;

    await act(async () => {
      component = create(
        <Screen safeTop={false}>
          <ScrollScreen safeTop={false} contentStyle={{paddingTop: 1}}>
            <IslamicOrnament light compact />
            <AppHeader eyebrow="Tahfidz" title="Perjalanan santri" subtitle="Bersama Al-Qur'an" />
            <HeroCard><Text>Hero Zabisa</Text></HeroCard>
            <Title>Judul</Title>
            <DisplayTitle>Judul utama</DisplayTitle>
            <DetailHeader eyebrow="Majelis" title="Kajian" subtitle="Ustaz Demo" icon="kajian" />
            <SectionTitle action={<Text>Aksi</Text>}>Bagian</SectionTitle>
            <Muted>Penjelasan</Muted>
            <Body>Isi utama</Body>
            <StatCard icon="tahfidz" value={12} label="Hafalan" />
          </ScrollScreen>
        </Screen>,
      );
      await Promise.resolve();
    });

    expect(component!.root.findAllByProps({accessibilityRole: 'header'}).length).toBeGreaterThan(1);
    expect(component!.root.findAllByType(Text).map(node => node.props.children)).toContain('Hero Zabisa');

    act(() => component!.unmount());
  });

  it('executes card, primary/secondary button, text action and service tile controls', () => {
    const onCard = jest.fn();
    const onPrimary = jest.fn();
    const onSecondary = jest.fn();
    const onText = jest.fn();
    const onTile = jest.fn();
    let component: ReactTestRenderer | undefined;

    act(() => {
      component = create(
        <View>
          <Card onPress={onCard}><Text>Card action</Text></Card>
          <Card><Text>Static card</Text></Card>
          <Button title="Simpan" icon="account" onPress={onPrimary} />
          <Button title="Batal" secondary color="#123456" softColor="#eeeeee" onPress={onSecondary} />
          <Button title="Tidak aktif" disabled onPress={jest.fn()} />
          <TextButton title="Lihat semua" onPress={onText} />
          <IconTile icon="donation" label="Berbagi" subtitle="Donasi" color="#654321" softColor="#fafafa" onPress={onTile} />
        </View>,
      );
    });

    const buttons = component!.root.findAllByProps({accessibilityRole: 'button'});
    const card = buttons.find(node => node.findAllByType(Text).some(text => text.props.children === 'Card action'))!;
    act(() => card.props.onPress());
    act(() => component!.root.findByProps({accessibilityLabel: 'Simpan'}).props.onPress());
    act(() => component!.root.findByProps({accessibilityLabel: 'Batal'}).props.onPress());
    act(() => component!.root.findByProps({accessibilityLabel: 'Lihat semua'}).props.onPress());
    act(() => component!.root.findByProps({accessibilityLabel: 'Berbagi'}).props.onPress());

    expect(onCard).toHaveBeenCalledTimes(1);
    expect(onPrimary).toHaveBeenCalledTimes(1);
    expect(onSecondary).toHaveBeenCalledTimes(1);
    expect(onText).toHaveBeenCalledTimes(1);
    expect(onTile).toHaveBeenCalledTimes(1);
    expect(component!.root.findByProps({accessibilityLabel: 'Tidak aktif'}).props.accessibilityState).toEqual({disabled: true});
  });

  it('renders field, status, loading, empty and retry branches', () => {
    const onChange = jest.fn();
    const onRetry = jest.fn();
    let component: ReactTestRenderer | undefined;

    act(() => {
      component = create(
        <View>
          <TextField label="Email" error="Email wajib" value="wali@example.test" onChangeText={onChange} />
          <Pill text="Normal" />
          <Pill text="Utama" tone="primary" />
          <Pill text="Sukses" tone="success" />
          <Pill text="Menunggu" tone="warning" />
          <Pill text="Gagal" tone="danger" />
          <Loading label="Sedang memuat" />
          <Empty text="Belum tersedia" icon="info" />
          <ErrorState message="Jaringan terputus" onRetry={onRetry} />
          <ErrorState />
        </View>,
      );
    });

    act(() => component!.root.findByType(TextInput).props.onChangeText('baru@example.test'));
    act(() => component!.root.findByProps({accessibilityLabel: 'Coba lagi'}).props.onPress());

    expect(onChange).toHaveBeenCalledWith('baru@example.test');
    expect(onRetry).toHaveBeenCalledTimes(1);
    expect(component!.root.findAllByType(Text).some(node => node.props.children === 'Email wajib')).toBe(true);
  });
});
