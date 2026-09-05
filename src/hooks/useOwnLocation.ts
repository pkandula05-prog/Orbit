import { useEffect, useState } from 'react';
import { Platform } from 'react-native';
import * as Location from 'expo-location';

import type { Coords } from '../lib/geo';
import { DEMO_ORIGIN } from '../services/mockSource';

export type OwnLocation = {
  coords: Coords;
  altitude: number | null;
  /** False while the demo origin is standing in for a real fix. */
  isLive: boolean;
};

const DEMO_ALTITUDE_M = 412;

/** The device's own position, which every bearing and distance on the dial is measured from. */
export function useOwnLocation(): OwnLocation {
  const [location, setLocation] = useState<OwnLocation>({
    coords: DEMO_ORIGIN,
    altitude: DEMO_ALTITUDE_M,
    isLive: false,
  });

  useEffect(() => {
    if (Platform.OS === 'web') return;

    let cancelled = false;
    let subscription: Location.LocationSubscription | undefined;

    const start = async () => {
      try {
        const { granted } = await Location.requestForegroundPermissionsAsync();
        if (cancelled || !granted) return;

        subscription = await Location.watchPositionAsync(
          { accuracy: Location.Accuracy.Balanced, distanceInterval: 10, timeInterval: 5000 },
          (reading) => {
            if (cancelled) return;
            setLocation({
              coords: {
                latitude: reading.coords.latitude,
                longitude: reading.coords.longitude,
              },
              altitude: reading.coords.altitude,
              isLive: true,
            });
          },
        );
        if (cancelled) subscription.remove();
      } catch {
        // Keep the demo origin; the screen stays usable without a fix.
      }
    };

    start();

    return () => {
      cancelled = true;
      subscription?.remove();
    };
  }, []);

  return location;
}
