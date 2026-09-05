import { bearingBetween, distanceBetween, isOnTarget, signedDelta, type Coords } from './geo';
import { isStale, type FriendLocation } from '../services/friendLocations';

export type FriendReading = {
  id: string;
  name: string;
  initial: string;
  /** True bearing from the device to the friend, degrees clockwise from north. */
  bearing: number;
  distanceM: number;
  /** Degrees to turn to face them: positive is clockwise. */
  delta: number;
  onTarget: boolean;
  stale: boolean;
  tracked: boolean;
};

export type CompassModel = {
  readings: FriendReading[];
  tracked: FriendReading[];
  nearest?: FriendReading;
  farthest?: FriendReading;
};

type BuildArgs = {
  friends: FriendLocation[];
  origin: Coords;
  heading: number;
  trackedIds: readonly string[];
  now?: number;
};

export function buildCompassModel({
  friends,
  origin,
  heading,
  trackedIds,
  now = Date.now(),
}: BuildArgs): CompassModel {
  const readings = friends.map<FriendReading>((friend) => {
    const bearing = bearingBetween(origin, friend);
    const delta = signedDelta(heading, bearing);

    return {
      id: friend.id,
      name: friend.name,
      initial: friend.initial,
      bearing,
      distanceM: distanceBetween(origin, friend),
      delta,
      onTarget: isOnTarget(delta),
      stale: isStale(friend, now),
      tracked: trackedIds.includes(friend.id),
    };
  });

  const tracked = readings.filter((reading) => reading.tracked);
  const byDistance = [...tracked].sort((a, b) => a.distanceM - b.distanceM);

  return {
    readings,
    tracked,
    nearest: byDistance[0],
    farthest: byDistance.length > 1 ? byDistance[byDistance.length - 1] : undefined,
  };
}
