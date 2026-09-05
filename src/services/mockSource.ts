import { destinationPoint, type Coords } from '../lib/geo';
import type { FriendLocation, FriendLocationSource } from './friendLocations';

export const DEMO_ORIGIN: Coords = { latitude: 37.7749, longitude: -122.4194 };

/** Bearings and distances are the ones drawn on artboards 5a/5b. */
const SEED = [
  { id: 'ana', name: 'Ana', initial: 'A', bearing: 47, metres: 1200, driftMps: 1.4 },
  { id: 'miles', name: 'Miles', initial: 'M', bearing: 112, metres: 3800, driftMps: 0.6 },
  { id: 'jae', name: 'Jae', initial: 'J', bearing: 205, metres: 5100, driftMps: 2.1 },
  { id: 'priya', name: 'Priya', initial: 'P', bearing: 298, metres: 640, driftMps: 0.9 },
  { id: 'noor', name: 'Noor', initial: 'N', bearing: 18, metres: 2400, driftMps: 0.4 },
  { id: 'tobi', name: 'Tobi', initial: 'T', bearing: 154, metres: 900, driftMps: 1.1 },
  { id: 'wren', name: 'Wren', initial: 'W', bearing: 241, metres: 7300, driftMps: 0.3 },
  { id: 'kai', name: 'Kai', initial: 'K', bearing: 331, metres: 1850, driftMps: 1.7 },
] as const;

export const DEFAULT_TRACKED_IDS = ['ana', 'miles'];

type MockSourceOptions = {
  origin?: Coords;
  /** Set to 0 to freeze positions, which is what the screenshot tests want. */
  updateMs?: number;
};

/**
 * Stand-in feed for development: the roster from the artboards, drifting slowly so the
 * bearings and distances behave like a live feed.
 */
export function createMockSource({
  origin = DEMO_ORIGIN,
  updateMs = 4000,
}: MockSourceOptions = {}): FriendLocationSource {
  const snapshot = (elapsedMs: number): FriendLocation[] =>
    SEED.map((friend, index) => {
      const seconds = elapsedMs / 1000;
      const wander = Math.sin(seconds / 30 + index) * friend.driftMps * 40;
      const point = destinationPoint(
        origin,
        friend.bearing + Math.sin(seconds / 45 + index) * 3,
        Math.max(60, friend.metres + wander),
      );

      return {
        id: friend.id,
        name: friend.name,
        initial: friend.initial,
        latitude: point.latitude,
        longitude: point.longitude,
        updatedAt: Date.now(),
      };
    });

  return {
    id: 'mock',
    label: 'Demo roster',
    subscribe(onUpdate) {
      const startedAt = Date.now();
      onUpdate(snapshot(0));

      if (updateMs <= 0) return () => {};

      const timer = setInterval(() => onUpdate(snapshot(Date.now() - startedAt)), updateMs);
      return () => clearInterval(timer);
    },
  };
}
