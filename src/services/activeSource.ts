import type { Coords } from '../lib/geo';
import { createRestSource, type FriendLocationSource } from './friendLocations';
import { createMockSource } from './mockSource';

const endpoint = process.env.EXPO_PUBLIC_ORBIT_FEED_URL;
const token = process.env.EXPO_PUBLIC_ORBIT_FEED_TOKEN;

export const usingMockFeed = !endpoint;

/**
 * `getOrigin` is only consulted by the mock feed, which scatters its roster around the
 * device. A real feed reports real coordinates and ignores it.
 */
export function createFriendLocationSource(getOrigin: () => Coords): FriendLocationSource {
  return endpoint ? createRestSource({ endpoint, token }) : createMockSource({ getOrigin });
}
