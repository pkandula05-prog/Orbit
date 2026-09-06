import { StyleSheet, Text, View } from 'react-native';

import { CompassRing } from './CompassRing';
import type { FriendReading } from '../lib/compassModel';
import { cardinalName, formatDelta, formatDistance, formatHeading } from '../lib/geo';
import { color, font } from '../theme/tokens';

const RING = 150;

/** Same lineHeight-clip fix as CompassReadout: box safely tall, tight stacking via negative margin. */
function Heading({ size, heading, align }: { size: number; heading: number; align?: 'center' }) {
  return (
    <>
      <Text
        style={{
          fontFamily: font.heading,
          fontSize: size,
          lineHeight: size,
          marginTop: -size * 0.08,
          marginBottom: -size * 0.08,
          letterSpacing: size * -0.04,
          color: color.ink,
          textAlign: align,
        }}
      >
        {formatHeading(heading)}
      </Text>
      <Text
        style={[
          styles.caps,
          { fontSize: size * 0.27, letterSpacing: size * 0.27 * 0.18, marginTop: size * 0.17, textAlign: align },
        ]}
      >
        {cardinalName(heading)}
      </Text>
    </>
  );
}

/** Artboard 6a — small home-screen widget: ring + heading, one marker. */
export function WidgetSmall({ heading, friend }: { heading: number; friend?: FriendReading }) {
  return (
    <View style={styles.small}>
      <View style={styles.ringArea}>
        <CompassRing size={RING} heading={heading} markers={friend ? [friend] : []} />
        <View style={styles.smallText}>
          <Heading size={30} heading={heading} />
        </View>
      </View>
    </View>
  );
}

/** Artboard 6b — medium home-screen widget: ring + heading, plus a two-friend tracking list. */
export function WidgetMedium({ heading, friends }: { heading: number; friends: FriendReading[] }) {
  return (
    <View style={styles.medium}>
      <View style={[styles.ringArea, { left: 14 }]}>
        <CompassRing size={RING} heading={heading} markers={friends} />
        <View style={styles.mediumText}>
          <Heading size={34} heading={heading} align="center" />
        </View>
      </View>

      <View style={styles.panel}>
        <View style={styles.panelHeader}>
          <Text style={[styles.caps, { fontSize: 9 }]}>Tracking</Text>
          <Text style={[styles.caps, styles.muted, { fontSize: 9 }]}>{friends.length}</Text>
        </View>

        {friends.map((f, i) => (
          <View key={f.id} style={[styles.row, i > 0 && styles.rowBorder]}>
            <View style={styles.badge}>
              <Text style={styles.badgeText}>{f.initial}</Text>
            </View>
            <View style={{ flex: 1 }}>
              <Text style={styles.name}>{f.name}</Text>
              <Text style={styles.dist}>{formatDistance(f.distanceM)}</Text>
            </View>
            <Text style={[styles.delta, { color: f.onTarget ? color.onTarget : color.red }]}>
              {formatDelta(f.delta)}
            </Text>
          </View>
        ))}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  small: {
    width: 170,
    height: 170,
    borderRadius: 22,
    backgroundColor: color.bg,
    overflow: 'hidden',
  },
  medium: {
    width: 364,
    height: 170,
    borderRadius: 22,
    backgroundColor: color.bg,
    overflow: 'hidden',
  },
  ringArea: {
    position: 'absolute',
    left: 10,
    top: 10,
    width: RING,
    height: RING,
  },
  smallText: {
    position: 'absolute',
    left: 22,
    top: 42,
    width: 86,
  },
  mediumText: {
    position: 'absolute',
    left: 0,
    right: 0,
    top: 42,
    alignItems: 'center',
  },
  panel: {
    position: 'absolute',
    left: 186,
    right: 18,
    top: 20,
    bottom: 20,
    justifyContent: 'space-between',
  },
  panelHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'baseline',
    paddingBottom: 8,
    borderBottomWidth: 2,
    borderBottomColor: color.ink,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'baseline',
    columnGap: 10,
  },
  rowBorder: {
    paddingTop: 10,
    borderTopWidth: 1,
    borderTopColor: color.neutral400,
  },
  badge: {
    width: 16,
    height: 16,
    backgroundColor: color.red,
    alignItems: 'center',
    justifyContent: 'center',
  },
  badgeText: {
    fontFamily: font.heading,
    fontSize: 9,
    color: color.bg,
  },
  name: {
    fontSize: 13,
    fontWeight: '600',
    color: color.ink,
  },
  dist: {
    fontFamily: font.mono,
    fontSize: 10,
    color: color.neutral700,
    marginTop: 2,
  },
  delta: {
    fontFamily: font.mono,
    fontWeight: '600',
    fontSize: 20,
  },
  caps: {
    fontFamily: font.caps,
    textTransform: 'uppercase',
    color: color.blue,
  },
  muted: {
    color: color.neutral700,
  },
});
