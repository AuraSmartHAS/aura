import React from 'react';
import { ActivityIndicator, Pressable, StyleSheet, Text } from 'react-native';
import { fontFamily, minTouchTarget, radius, theme } from '../theme';

type Variant = 'primary' | 'secondary' | 'outline';

type Props = {
  title: string;
  onPress: () => void;
  variant?: Variant;
  disabled?: boolean;
  loading?: boolean;
};

/**
 * Botão do design system AURA (espelha `FilledButton`/`OutlinedButton` de
 * `mobile/lib/core/theme/app_theme.dart`): alvo de toque >= 48dp, cantos 12,
 * rótulo em Atkinson Hyperlegible bold.
 */
export default function AuraButton({ title, onPress, variant = 'primary', disabled, loading }: Props) {
  const isOutline = variant === 'outline';
  const bg = disabled
    ? theme.border
    : variant === 'primary'
      ? theme.primary
      : variant === 'secondary'
        ? theme.careGreen
        : 'transparent';
  const fg = isOutline ? theme.primary : '#FFFFFF';

  return (
    <Pressable
      onPress={onPress}
      disabled={disabled || loading}
      accessibilityRole="button"
      accessibilityLabel={title}
      style={({ pressed }) => [
        styles.base,
        { backgroundColor: bg },
        isOutline && styles.outline,
        pressed && !disabled && styles.pressed,
      ]}
    >
      {loading ? (
        <ActivityIndicator color={fg} />
      ) : (
        <Text style={[styles.label, { color: isOutline && !disabled ? theme.primary : fg }]}>{title}</Text>
      )}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  base: {
    minHeight: minTouchTarget + 4,
    borderRadius: radius.md,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 24,
  },
  outline: {
    borderWidth: 1.5,
    borderColor: theme.primary,
  },
  pressed: {
    opacity: 0.85,
  },
  label: {
    fontFamily: fontFamily.bodyBold,
    fontSize: 16,
  },
});
