import { useEffect, useRef } from 'react';
import { Animated, StyleSheet, Text, View } from 'react-native';

import { cardinalName, formatDelta, formatHeading } from '../lib/geo';
import type { FriendReading } from '../lib/compassModel';
import { color, font } from '../theme/tokens';

/** The artboards draw this block inside a 373pt dial. */
const DIAL_UNITS = 373;

type CompassReadoutProps = {
  ringSize: number;
  heading: number;
  tracked: FriendReading[];
  /** Artboard 5b: three or more tracked friends, so deltas move to a two-column grid. */
  dense: boolean;
};

export function CompassReadout({ ringSize, heading, tracked, dense }: CompassReadoutProps) {
  const u = (value: number) => (value / DIAL_UNITS) * ringSize;

  // Adding a 3rd+ tracked friend shrinks and raises the numeral (5b's layout) — animate that
  // shift instead of snapping.
  const denseAnim = useRef(new Animated.Value(dense ? 1 : 0)).current;
  useEffect(() => {
    Animated.timing(denseAnim, { toValue: dense ? 1 : 0, duration: 260, useNativeDriver: false }).start();
  }, [dense, denseAnim]);

  const top = denseAnim.interpolate({ inputRange: [0, 1], outputRange: [u(118), u(106)] });
  const headingSize = denseAnim.interpolate({ inputRange: [0, 1], outputRange: [u(66), u(56)] });
  const headingMargin = Animated.multiply(headingSize, -0.08);

  return (
    <Animated.View
      pointerEvents="none"
      style={[styles.block, { left: u(84), top, width: u(200) }]}
    >
      <Animated.Text
        style={{
          fontFamily: font.heading,
          fontSize: headingSize,
          // A line box tighter than the font's own metrics (the artboards' CSS line-height:
          // .84) clips the glyph tops on native Text, even though it renders fine on web —
          // react-native-web maps this to a CSS line-height, which browsers never clip.
          // Keep the box safely tall, and pull the tight stacking back in with negative margin.
          lineHeight: headingSize,
          marginTop: headingMargin,
          marginBottom: headingMargin,
          letterSpacing: Animated.multiply(headingSize, -0.04),
          color: color.ink,
        }}
      >
        {formatHeading(heading)}
      </Animated.Text>

      <Text style={[styles.caps, { fontSize: u(11), letterSpacing: u(11) * 0.18, marginTop: u(8) }]}>
        {cardinalName(heading)}
      </Text>

      {tracked.length > 0 && (
        <View
          style={[
            styles.rule,
            dense
              ? { width: u(190), marginTop: u(14), paddingTop: u(10) }
              : { width: u(190), marginTop: u(18), paddingTop: u(12) },
            dense && styles.grid,
          ]}
        >
          {tracked.map((friend) => (
            <View
              key={friend.id}
              style={
                dense
                  ? [styles.gridCell, { width: (u(190) - u(16)) / 2, marginBottom: u(6) }]
                  : [styles.row, { marginBottom: u(2) }]
              }
            >
              <Text
                style={[
                  styles.caps,
                  styles.name,
                  dense
                    ? { fontSize: u(10), letterSpacing: u(10) * 0.18 }
                    : { fontSize: u(11), letterSpacing: u(11) * 0.18, flex: 1 },
                ]}
                numberOfLines={1}
              >
                {friend.name}
              </Text>
              <Text
                style={{
                  fontFamily: font.mono,
                  fontWeight: '600',
                  fontSize: u(dense ? 17 : 19),
                  color: friend.onTarget ? color.onTarget : color.red,
                }}
              >
                {formatDelta(friend.delta)}
              </Text>
            </View>
          ))}
        </View>
      )}
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  block: {
    position: 'absolute',
    zIndex: 3,
  },
  caps: {
    fontFamily: font.caps,
    textTransform: 'uppercase',
    color: color.blue,
  },
  name: {
    color: color.neutral700,
  },
  rule: {
    borderTopWidth: 1,
    borderTopColor: color.neutral400,
  },
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
  },
  gridCell: {
    flexDirection: 'column',
  },
  row: {
    flexDirection: 'row',
    alignItems: 'baseline',
    columnGap: 12,
  },
});
