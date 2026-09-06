import React from 'react';
import {AccessibilityInfo, Animated, type StyleProp, type ViewStyle} from 'react-native';
import {depth, motion} from '../theme/tokens';

export function useReducedMotion() {
  const [reduced, setReduced] = React.useState(false);

  React.useEffect(() => {
    let mounted = true;
    AccessibilityInfo.isReduceMotionEnabled()
      .then(value => {
        // The initial state already represents normal motion. Avoid scheduling
        // a redundant async update, which can outlive short-lived renderers in
        // unit tests and does no useful work at runtime.
        if (mounted && value) setReduced(true);
      })
      .catch(() => undefined);

    const subscription = AccessibilityInfo.addEventListener?.('reduceMotionChanged', setReduced);
    return () => {
      mounted = false;
      subscription?.remove();
    };
  }, []);

  return reduced;
}

export function AnimatedPressDepth({children, pressed, style}: {children: React.ReactNode; pressed: boolean; style?: StyleProp<ViewStyle>}) {
  const reduced = useReducedMotion();
  const value = React.useRef(new Animated.Value(0)).current;

  React.useEffect(() => {
    if (reduced) {
      value.setValue(pressed ? 1 : 0);
      return;
    }
    Animated.spring(value, {
      toValue: pressed ? 1 : 0,
      damping: 18,
      stiffness: 240,
      mass: 0.45,
      useNativeDriver: true,
    }).start();
  }, [pressed, reduced, value]);

  const translateY = value.interpolate({inputRange: [0, 1], outputRange: [0, depth.press]});
  const scale = value.interpolate({inputRange: [0, 1], outputRange: [1, 0.992]});

  return <Animated.View style={[style, {transform: [{translateY}, {scale}]}]}>{children}</Animated.View>;
}

export function usePulseAnimation() {
  const reduced = useReducedMotion();
  const value = React.useRef(new Animated.Value(0.58)).current;

  React.useEffect(() => {
    value.stopAnimation();
    if (reduced) {
      value.setValue(0.72);
      return;
    }
    const animation = Animated.loop(
      Animated.sequence([
        Animated.timing(value, {toValue: 1, duration: motion.standard * 3, useNativeDriver: true}),
        Animated.timing(value, {toValue: 0.58, duration: motion.standard * 3, useNativeDriver: true}),
      ]),
    );
    animation.start();
    return () => animation.stop();
  }, [reduced, value]);

  return value;
}
