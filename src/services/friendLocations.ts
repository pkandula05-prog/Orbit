import type { Coords } from '../lib/geo';

export type FriendLocation = Coords & {
  id: string;
  name: string;
  /** Single glyph shown in the ring marker and the tracking tile. */
  initial: string;
  /** Epoch ms of the fix. Stale fixes are still shown, just marked stale. */
  updatedAt: number;
};

/**
 * Any feed of friend positions Orbit can point the compass at.
 *
 * Apple's Find My is a closed system with no public API, so this is the seam where a
 * feed you do control gets plugged in — see README.md for the supported options.
 */
export interface FriendLocationSource {
  readonly id: string;
  readonly label: string;
  /** Pushes the full roster on every update. Returns an unsubscribe function. */
  subscribe(onUpdate: (friends: FriendLocation[]) => void): () => void;
}

export const STALE_AFTER_MS = 5 * 60 * 1000;

export function isStale(friend: FriendLocation, now = Date.now()): boolean {
  return now - friend.updatedAt > STALE_AFTER_MS;
}

type RestSourceOptions = {
  endpoint: string;
  /** Sent as `Authorization: Bearer <token>` when present. */
  token?: string;
  pollMs?: number;
  onError?: (error: unknown) => void;
};

type RestPayload = {
  friends: Array<{
    id: string;
    name: string;
    initial?: string;
    latitude: number;
    longitude: number;
    updatedAt?: number | string;
  }>;
};

function parseTimestamp(value: number | string | undefined): number {
  if (typeof value === 'number') return value;
  if (typeof value === 'string') {
    const parsed = Date.parse(value);
    if (!Number.isNaN(parsed)) return parsed;
  }
  return Date.now();
}

/**
 * Polls a JSON endpoint shaped like `{ friends: [{ id, name, latitude, longitude, updatedAt }] }`.
 */
export function createRestSource({
  endpoint,
  token,
  pollMs = 15000,
  onError,
}: RestSourceOptions): FriendLocationSource {
  return {
    id: 'rest',
    label: 'Shared feed',
    subscribe(onUpdate) {
      let cancelled = false;
      const controller = new AbortController();

      const poll = async () => {
        try {
          const response = await fetch(endpoint, {
            signal: controller.signal,
            headers: token ? { Authorization: `Bearer ${token}` } : undefined,
          });
          if (!response.ok) throw new Error(`Friend feed responded ${response.status}`);

          const payload = (await response.json()) as RestPayload;
          if (cancelled) return;

          onUpdate(
            payload.friends.map((friend) => ({
              id: friend.id,
              name: friend.name,
              initial: friend.initial ?? friend.name.slice(0, 1).toUpperCase(),
              latitude: friend.latitude,
              longitude: friend.longitude,
              updatedAt: parseTimestamp(friend.updatedAt),
            })),
          );
        } catch (error) {
          if (!cancelled) onError?.(error);
        }
      };

      poll();
      const timer = setInterval(poll, pollMs);

      return () => {
        cancelled = true;
        controller.abort();
        clearInterval(timer);
      };
    },
  };
}
