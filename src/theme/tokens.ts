import { Platform } from 'react-native';

// The `modernist` design system's styles.css was not reachable from this environment,
// so the neutral ramp below is matched by eye to the bg/ink endpoints it is used between.
export const color = {
  bg: '#f3f2f2',
  ink: '#201e1d',
  red: '#ec3013',
  blue: '#1b3fa8',
  yellow: '#fbc417',
  onTarget: '#34C759',
  case: '#141414',

  neutral300: '#d9d7d5',
  neutral400: '#c4c1be',
  neutral500: '#a8a4a0',
  neutral600: '#7d7975',
  neutral700: '#5c5854',
} as const;

export const font = {
  heading: 'Archivo_700Bold',
  headingRegular: 'Archivo_400Regular',
  caps: 'Archivo_600SemiBold',
  mono: Platform.select({ ios: 'Menlo', android: 'monospace', default: 'ui-monospace' })!,
} as const;

/** Caps micro-label used for nearly every piece of secondary text in the design. */
export const caps = {
  fontFamily: font.caps,
  fontSize: 11,
  letterSpacing: 11 * 0.18,
  textTransform: 'uppercase',
} as const;

export const monoNumeral = {
  fontFamily: font.mono,
  fontWeight: '600',
} as const;

/** The artboards are drawn at 393pt wide; scale keeps proportions on other devices. */
export const DESIGN_WIDTH = 393;

export function scaler(screenWidth: number) {
  const ratio = Math.min(Math.max(screenWidth / DESIGN_WIDTH, 0.85), 1.25);
  return (value: number) => Math.round(value * ratio * 100) / 100;
}
