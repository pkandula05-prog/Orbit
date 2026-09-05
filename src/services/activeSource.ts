import { createRestSource, type FriendLocationSource } from './friendLocations';
import { createMockSource } from './mockSource';

const endpoint = process.env.EXPO_PUBLIC_ORBIT_FEED_URL;
const token = process.env.EXPO_PUBLIC_ORBIT_FEED_TOKEN;

export const friendLocationSource: FriendLocationSource = endpoint
  ? createRestSource({ endpoint, token })
  : createMockSource();
