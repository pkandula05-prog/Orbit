export type Coords = { latitude: number; longitude: number };

const EARTH_RADIUS_M = 6371008.8;
const toRad = (deg: number) => (deg * Math.PI) / 180;
const toDeg = (rad: number) => (rad * 180) / Math.PI;

export function normalizeDegrees(deg: number): number {
  const wrapped = deg % 360;
  return wrapped < 0 ? wrapped + 360 : wrapped;
}

/** Signed shortest turn from `from` to `to`, in (-180, 180]. */
export function signedDelta(from: number, to: number): number {
  let delta = normalizeDegrees(to) - normalizeDegrees(from);
  if (delta > 180) delta -= 360;
  if (delta <= -180) delta += 360;
  return delta;
}

/** Initial great-circle bearing from `a` to `b`, in degrees clockwise from true north. */
export function bearingBetween(a: Coords, b: Coords): number {
  const lat1 = toRad(a.latitude);
  const lat2 = toRad(b.latitude);
  const dLon = toRad(b.longitude - a.longitude);

  const y = Math.sin(dLon) * Math.cos(lat2);
  const x = Math.cos(lat1) * Math.sin(lat2) - Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLon);

  return normalizeDegrees(toDeg(Math.atan2(y, x)));
}

/** Great-circle distance in metres (haversine). */
export function distanceBetween(a: Coords, b: Coords): number {
  const lat1 = toRad(a.latitude);
  const lat2 = toRad(b.latitude);
  const dLat = toRad(b.latitude - a.latitude);
  const dLon = toRad(b.longitude - a.longitude);

  const h =
    Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;

  return 2 * EARTH_RADIUS_M * Math.asin(Math.min(1, Math.sqrt(h)));
}

/** Point reached by travelling `distanceM` from `origin` along `bearing`. */
export function destinationPoint(origin: Coords, bearing: number, distanceM: number): Coords {
  const angular = distanceM / EARTH_RADIUS_M;
  const lat1 = toRad(origin.latitude);
  const lon1 = toRad(origin.longitude);
  const brg = toRad(bearing);

  const lat2 = Math.asin(
    Math.sin(lat1) * Math.cos(angular) + Math.cos(lat1) * Math.sin(angular) * Math.cos(brg),
  );
  const lon2 =
    lon1 +
    Math.atan2(
      Math.sin(brg) * Math.sin(angular) * Math.cos(lat1),
      Math.cos(angular) - Math.sin(lat1) * Math.sin(lat2),
    );

  return { latitude: toDeg(lat2), longitude: ((toDeg(lon2) + 540) % 360) - 180 };
}

const CARDINALS = [
  'North',
  'Northeast',
  'East',
  'Southeast',
  'South',
  'Southwest',
  'West',
  'Northwest',
] as const;

export function cardinalName(heading: number): string {
  return CARDINALS[Math.round(normalizeDegrees(heading) / 45) % 8];
}

/** The artboards quantise every numeral to 2°, which also stops the readout flickering. */
export function quantizeDegrees(deg: number): number {
  return (Math.round(deg / 2) * 2) % 360;
}

export function formatHeading(heading: number): string {
  return `${String(quantizeDegrees(normalizeDegrees(heading))).padStart(3, '0')}°`;
}

export function formatDelta(delta: number): string {
  const sign = delta >= 0 ? '+' : '−';
  const magnitude = Math.abs(Math.round(delta / 2) * 2);
  return `${sign}${String(magnitude).padStart(3, '0')}°`;
}

export const ON_TARGET_DEGREES = 10;

export function isOnTarget(delta: number): boolean {
  return Math.abs(delta) <= ON_TARGET_DEGREES;
}

export function formatDistance(metres: number): string {
  if (!Number.isFinite(metres)) return '—';
  if (metres < 1000) return `${Math.round(metres / 10) * 10} m`;
  if (metres < 10000) return `${(metres / 1000).toFixed(1)} km`;
  return `${Math.round(metres / 1000)} km`;
}
