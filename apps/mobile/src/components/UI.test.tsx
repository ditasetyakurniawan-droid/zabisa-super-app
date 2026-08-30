import React from 'react';
import {describe, expect, it, jest} from '@jest/globals';
import {act, create} from 'react-test-renderer';
import {TextInput} from 'react-native';
import {TextField} from './UI';

jest.mock('react-native-safe-area-context', () => ({
  SafeAreaView: ({children}: {children: React.ReactNode}) => children,
  useSafeAreaInsets: () => ({top: 0, right: 0, bottom: 0, left: 0}),
}));

describe('TextField password visibility', () => {
  it('masks password by default and can reveal it explicitly', () => {
    let component: ReturnType<typeof create> | undefined;
    act(() => { component = create(<TextField value="ChangeMe123!" secureTextEntry secureToggle onChangeText={() => undefined} />); });
    expect(component!.root.findByType(TextInput).props.secureTextEntry).toBe(true);
    const toggle = component!.root.findByProps({accessibilityLabel: 'Tampilkan password'});
    expect(toggle.props.accessibilityRole).toBe('button');
    act(() => { toggle.props.onPress(); });
    expect(component!.root.findByType(TextInput).props.secureTextEntry).toBe(false);
    expect(component!.root.findByProps({accessibilityLabel: 'Sembunyikan password'})).toBeDefined();
  });
});
