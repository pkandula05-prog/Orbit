import {
  Archivo_400Regular,
  Archivo_600SemiBold,
  Archivo_700Bold,
  useFonts,
} from '@expo-google-fonts/archivo';
import { StatusBar } from 'expo-status-bar';
import { View } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { CompassFaceScreen } from './src/screens/CompassFaceScreen';
import { color } from './src/theme/tokens';

export default function App() {
  const [fontsLoaded] = useFonts({
    Archivo_400Regular,
    Archivo_600SemiBold,
    Archivo_700Bold,
  });

  return (
    <SafeAreaProvider>
      <StatusBar style="dark" />
      {fontsLoaded ? (
        <CompassFaceScreen />
      ) : (
        <View style={{ flex: 1, backgroundColor: color.bg }} />
      )}
    </SafeAreaProvider>
  );
}
