import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import type { FriendReading } from '../lib/compassModel';
import { color, font } from '../theme/tokens';

type TrackingRowProps = {
  friends: FriendReading[];
  onToggle: (id: string) => void;
};

export function TrackingRow({ friends, onToggle }: TrackingRowProps) {
  return (
    <ScrollView
      horizontal
      showsHorizontalScrollIndicator={false}
      contentContainerStyle={styles.row}
    >
      {friends.map((friend) => (
        <Pressable
          key={friend.id}
          onPress={() => onToggle(friend.id)}
          accessibilityRole="switch"
          accessibilityState={{ checked: friend.tracked }}
          accessibilityLabel={`Track ${friend.name}`}
          style={styles.tile}
        >
          <View style={[styles.badge, friend.tracked ? styles.badgeOn : styles.badgeOff]}>
            <Text style={[styles.initial, friend.tracked ? styles.initialOn : styles.initialOff]}>
              {friend.initial}
            </Text>
          </View>
          <Text
            style={[styles.name, friend.tracked ? styles.nameOn : styles.nameOff]}
            numberOfLines={1}
          >
            {friend.name}
          </Text>
        </Pressable>
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    columnGap: 10,
  },
  tile: {
    width: 54,
    alignItems: 'center',
    rowGap: 6,
  },
  badge: {
    width: 54,
    height: 54,
    alignItems: 'center',
    justifyContent: 'center',
  },
  badgeOn: {
    backgroundColor: color.red,
  },
  badgeOff: {
    borderWidth: 2,
    borderColor: color.neutral500,
  },
  initial: {
    fontFamily: font.heading,
    fontSize: 20,
  },
  initialOn: {
    color: color.bg,
  },
  initialOff: {
    color: color.neutral700,
  },
  name: {
    fontFamily: font.caps,
    fontSize: 11,
    letterSpacing: 11 * 0.18,
    textTransform: 'uppercase',
  },
  nameOn: {
    color: color.ink,
  },
  nameOff: {
    color: color.neutral700,
  },
});
