import { useState } from 'react';
import {
  Archivo_400Regular,
  Archivo_600SemiBold,
  Archivo_700Bold,
  useFonts,
} from '@expo-google-fonts/archivo';
import { StatusBar } from 'expo-status-bar';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { SafeAreaProvider, useSafeAreaInsets } from 'react-native-safe-area-context';

import { CompassFaceScreen } from './src/screens/CompassFaceScreen';
import { WidgetsScreen } from './src/screens/WidgetsScreen';
import { color, font } from './src/theme/tokens';

function Root() {
  const insets = useSafeAreaInsets();
  const [showWidgets, setShowWidgets] = useState(false);

  return (
    <View style={{ flex: 1 }}>
      <StatusBar style={showWidgets ? 'light' : 'dark'} />
      {showWidgets ? <WidgetsScreen /> : <CompassFaceScreen />}
      <Pressable
        onPress={() => setShowWidgets((v) => !v)}
        style={[styles.toggle, { top: insets.top + 8 }]}
      >
        <Text style={styles.toggleText}>{showWidgets ? 'App' : 'Widgets'}</Text>
      </Pressable>
    </View>
  );
}

export default function App() {
  const [fontsLoaded] = useFonts({
    Archivo_400Regular,
    Archivo_600SemiBold,
    Archivo_700Bold,
  });

  return (
    <SafeAreaProvider>
      {fontsLoaded ? <Root /> : <View style={{ flex: 1, backgroundColor: color.bg }} />}
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  toggle: {
    position: 'absolute',
    right: 12,
    paddingVertical: 6,
    paddingHorizontal: 12,
    backgroundColor: color.ink,
    borderRadius: 14,
  },
  toggleText: {
    fontFamily: font.caps,
    fontSize: 11,
    letterSpacing: 11 * 0.18,
    textTransform: 'uppercase',
    color: color.bg,
  },
});
