import { useCallback, useMemo, useRef, useState } from 'react';
import { StyleSheet, Text, View, useWindowDimensions } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { CompassReadout } from '../components/CompassReadout';
import { CompassRing } from '../components/CompassRing';
import { TrackingRow } from '../components/TrackingRow';
import { useFriendLocations } from '../hooks/useFriendLocations';
import { useHeading } from '../hooks/useHeading';
import { useOwnLocation } from '../hooks/useOwnLocation';
import { buildCompassModel, type FriendReading } from '../lib/compassModel';
import { formatDistance } from '../lib/geo';
import { createFriendLocationSource } from '../services/activeSource';
import { DEFAULT_TRACKED_IDS } from '../services/mockSource';
import { color, font } from '../theme/tokens';

/** Three or more tracked friends switches the readout to the 5b grid layout. */
const DENSE_THRESHOLD = 3;
/** 5b's own readout only has room for a 2x2 grid — four is the most the dial can show clearly. */
const MAX_TRACKED = 4;
const SIDE_PADDING = 32;
const DIAL_MARGIN = 10;

function summarise(friend: FriendReading | undefined, prefix?: string): string {
  if (!friend) return '—';
  const label = prefix ? `${prefix} ${friend.name}` : friend.name;
  return `${label} ${formatDistance(friend.distanceM)}`;
}

export function CompassFaceScreen() {
  const insets = useSafeAreaInsets();
  const { width, height } = useWindowDimensions();

  const [trackedIds, setTrackedIds] = useState<string[]>(DEFAULT_TRACKED_IDS);

  const own = useOwnLocation();
  const { heading } = useHeading();

  // Read through a ref so the source is built once but always sees the latest fix.
  const originRef = useRef(own.coords);
  originRef.current = own.coords;
  const source = useMemo(() => createFriendLocationSource(() => originRef.current), []);

  const friends = useFriendLocations(source);

  const model = useMemo(
    () => buildCompassModel({ friends, origin: own.coords, heading, trackedIds }),
    [friends, own.coords, heading, trackedIds],
  );

  const toggle = useCallback((id: string) => {
    setTrackedIds((current) => {
      if (current.includes(id)) return current.filter((entry) => entry !== id);
      if (current.length >= MAX_TRACKED) return current;
      return [...current, id];
    });
  }, []);

  const dense = model.tracked.length >= DENSE_THRESHOLD;
  const ringSize = Math.min(width - DIAL_MARGIN * 2, height * 0.46);

  const headerRight =
    dense || own.altitude === null
      ? `${model.tracked.length} tracked`
      : `Alt ${Math.round(own.altitude)} m`;

  const [footerLeft, footerRight] = dense
    ? [summarise(model.nearest, 'Nearest'), summarise(model.farthest, 'Farthest')]
    : [summarise(model.tracked[0]), model.tracked[1] ? summarise(model.tracked[1]) : ''];

  return (
    <View style={[styles.screen, { paddingTop: insets.top + 20 }]}>
      <View style={styles.header}>
        <Text style={[styles.caps, styles.capsInk]}>Compass</Text>
        <Text style={[styles.caps, styles.capsMuted]}>{headerRight}</Text>
      </View>

      <View style={styles.dial}>
        <View style={{ width: ringSize, height: ringSize }}>
          <CompassRing size={ringSize} heading={heading} markers={model.tracked} />
          <CompassReadout
            ringSize={ringSize}
            heading={heading}
            tracked={model.tracked}
            dense={dense}
          />
        </View>
      </View>

      <View style={[styles.footer, { paddingBottom: insets.bottom + 38 }]}>
        <Text style={[styles.caps, styles.capsMuted, styles.footerCaption]}>
          {model.readings.length > 0 ? 'Tracking · tap to toggle' : 'Waiting for friend feed'}
        </Text>

        <TrackingRow friends={model.readings} onToggle={toggle} maxTracked={MAX_TRACKED} />

        <View style={styles.summary}>
          <Text style={[styles.caps, styles.capsInk, styles.summaryItem]} numberOfLines={1}>
            {model.tracked.length > 0 ? footerLeft : 'Nobody tracked'}
          </Text>
          <Text
            style={[styles.caps, styles.capsMuted, styles.summaryItem, styles.summaryRight]}
            numberOfLines={1}
          >
            {footerRight}
          </Text>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: color.bg,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'baseline',
    marginHorizontal: SIDE_PADDING,
    paddingBottom: 14,
    borderBottomWidth: 2,
    borderBottomColor: color.ink,
  },
  dial: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  footer: {
    paddingHorizontal: SIDE_PADDING,
  },
  footerCaption: {
    paddingBottom: 12,
  },
  summary: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'baseline',
    marginTop: 20,
    paddingTop: 14,
    borderTopWidth: 2,
    borderTopColor: color.ink,
    columnGap: 12,
  },
  summaryItem: {
    flexShrink: 1,
  },
  summaryRight: {
    textAlign: 'right',
  },
  caps: {
    fontFamily: font.caps,
    fontSize: 11,
    letterSpacing: 11 * 0.18,
    textTransform: 'uppercase',
  },
  capsInk: {
    color: color.ink,
  },
  capsMuted: {
    color: color.neutral700,
  },
});
