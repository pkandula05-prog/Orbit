import { useMemo, useRef } from 'react';
import { StyleSheet, View } from 'react-native';

import { WidgetMedium, WidgetSmall } from '../components/Widgets';
import { useFriendLocations } from '../hooks/useFriendLocations';
import { useHeading } from '../hooks/useHeading';
import { useOwnLocation } from '../hooks/useOwnLocation';
import { buildCompassModel } from '../lib/compassModel';
import { createFriendLocationSource } from '../services/activeSource';
import { DEFAULT_TRACKED_IDS } from '../services/mockSource';
import { color } from '../theme/tokens';

/** Artboards 6a/6b: the widgets always show the app's default pair (Ana, Miles). */
export function WidgetsScreen() {
  const own = useOwnLocation();
  const { heading } = useHeading();

  const originRef = useRef(own.coords);
  originRef.current = own.coords;
  const source = useMemo(() => createFriendLocationSource(() => originRef.current), []);
  const friends = useFriendLocations(source);

  const model = useMemo(
    () => buildCompassModel({ friends, origin: own.coords, heading, trackedIds: DEFAULT_TRACKED_IDS }),
    [friends, own.coords, heading],
  );

  return (
    <View style={styles.screen}>
      <WidgetSmall heading={heading} friend={model.tracked[0]} />
      <WidgetMedium heading={heading} friends={model.tracked} />
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: '#2a2725',
    alignItems: 'center',
    justifyContent: 'center',
    rowGap: 24,
  },
});
