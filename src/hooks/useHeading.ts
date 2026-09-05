import { useEffect, useRef, useState } from 'react';
import { Platform } from 'react-native';
import * as Location from 'expo-location';

import { normalizeDegrees } from '../lib/geo';

export type HeadingOrigin = 'device' | 'simulated';

export type HeadingReading = {
  heading: number;
  origin: HeadingOrigin;
};

/** Matches the sweep speed the artboards animate at. */
const SIMULATED_DEGREES_PER_SECOND = 7;
const UPDATE_INTERVAL_MS = 50;
const SMOOTHING = 0.25;

/** Low-pass filter on the unit vector, so 359°→001° does not swing the dial the long way. */
function smoothHeading(previous: number | null, next: number): number {
  if (previous === null) return next;

  const toRad = Math.PI / 180;
  const x = (1 - SMOOTHING) * Math.cos(previous * toRad) + SMOOTHING * Math.cos(next * toRad);
  const y = (1 - SMOOTHING) * Math.sin(previous * toRad) + SMOOTHING * Math.sin(next * toRad);

  return normalizeDegrees(Math.atan2(y, x) / toRad);
}

/**
 * True heading from the device compass. Where no compass is available — web, simulators —
 * the dial sweeps instead, so the screen can still be developed and reviewed.
 */
export function useHeading(enabled = true): HeadingReading {
  const [heading, setHeading] = useState(0);
  const [origin, setOrigin] = useState<HeadingOrigin>('simulated');
  const smoothed = useRef<number | null>(null);

  useEffect(() => {
    if (!enabled) return;

    let cancelled = false;
    let subscription: Location.LocationSubscription | undefined;
    let simulationTimer: ReturnType<typeof setInterval> | undefined;

    const simulate = () => {
      if (cancelled) return;
      setOrigin('simulated');
      const startedAt = Date.now();
      simulationTimer = setInterval(() => {
        const seconds = (Date.now() - startedAt) / 1000;
        setHeading(normalizeDegrees(seconds * SIMULATED_DEGREES_PER_SECOND));
      }, UPDATE_INTERVAL_MS);
    };

    const start = async () => {
      if (Platform.OS === 'web') {
        simulate();
        return;
      }

      try {
        const { granted } = await Location.requestForegroundPermissionsAsync();
        if (cancelled) return;
        if (!granted) {
          simulate();
          return;
        }

        subscription = await Location.watchHeadingAsync((reading) => {
          if (cancelled) return;
          const raw = reading.trueHeading >= 0 ? reading.trueHeading : reading.magHeading;
          smoothed.current = smoothHeading(smoothed.current, normalizeDegrees(raw));
          setHeading(smoothed.current);
        });
        if (cancelled) {
          subscription.remove();
          return;
        }
        setOrigin('device');
      } catch {
        if (!cancelled) simulate();
      }
    };

    start();

    return () => {
      cancelled = true;
      subscription?.remove();
      if (simulationTimer) clearInterval(simulationTimer);
    };
  }, [enabled]);

  return { heading, origin };
}
