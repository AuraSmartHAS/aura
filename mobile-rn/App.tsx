import { NavigationContainer, DefaultTheme } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import {
  BricolageGrotesque_600SemiBold,
  BricolageGrotesque_700Bold,
} from '@expo-google-fonts/bricolage-grotesque';
import {
  AtkinsonHyperlegible_400Regular,
  AtkinsonHyperlegible_700Bold,
} from '@expo-google-fonts/atkinson-hyperlegible';
import { useFonts } from 'expo-font';
import * as SplashScreen from 'expo-splash-screen';
import { StatusBar } from 'expo-status-bar';
import React, { useCallback, useEffect } from 'react';
import { Pressable, Text, View } from 'react-native';
import { setRole, setToken } from './src/api';
import { initPush, navigationRef, unregisterPushToken } from './src/push';
import CareChainScreen from './src/screens/CareChainScreen';
import DashboardScreen from './src/screens/DashboardScreen';
import EmergencyAlertScreen from './src/screens/EmergencyAlertScreen';
import LoginScreen from './src/screens/LoginScreen';
import MedicationsScreen from './src/screens/MedicationsScreen';
import type { RootStackParamList } from './src/navigation';
import { fontFamily, minTouchTarget, theme } from './src/theme';

const Stack = createNativeStackNavigator<RootStackParamList>();

SplashScreen.preventAutoHideAsync();

const navigationTheme = {
  ...DefaultTheme,
  colors: {
    ...DefaultTheme.colors,
    background: theme.bg,
    card: theme.bg,
    text: theme.textStrong,
    border: theme.border,
    primary: theme.primary,
  },
};

/** Navegação entre telas com React Navigation (native stack). */
export default function App() {
  const [fontsLoaded] = useFonts({
    BricolageGrotesque_600SemiBold,
    BricolageGrotesque_700Bold,
    AtkinsonHyperlegible_400Regular,
    AtkinsonHyperlegible_700Bold,
  });

  // canais e listeners do push antes de qualquer tela: o toque que abriu o app chega cedo
  useEffect(() => {
    initPush().catch(() => undefined);
  }, []);

  const onLayoutRootView = useCallback(async () => {
    if (fontsLoaded) {
      await SplashScreen.hideAsync();
    }
  }, [fontsLoaded]);

  if (!fontsLoaded) {
    return null;
  }

  return (
    <View style={{ flex: 1 }} onLayout={onLayoutRootView}>
      <NavigationContainer ref={navigationRef} theme={navigationTheme}>
        <StatusBar style="dark" />
        <Stack.Navigator
          initialRouteName="Login"
          screenOptions={{
            headerStyle: { backgroundColor: theme.bg },
            headerShadowVisible: false,
            headerTintColor: theme.ink,
            headerTitleStyle: { fontFamily: fontFamily.displaySemibold, fontSize: 19 },
            contentStyle: { backgroundColor: theme.bg },
          }}
        >
          <Stack.Screen name="Login" component={LoginScreen} options={{ headerShown: false }} />
          <Stack.Screen
            name="Dashboard"
            component={DashboardScreen}
            options={({ navigation }) => ({
              title: 'Painel da cuidadora',
              headerRight: () => (
                <Pressable
                  accessibilityRole="button"
                  accessibilityLabel="Sair"
                  style={{ minHeight: minTouchTarget, justifyContent: 'center', paddingHorizontal: 8 }}
                  onPress={async () => {
                    // com a sessão ainda viva: o desregistro do aparelho é autenticado
                    await unregisterPushToken();
                    setToken(null);
                    setRole(null);
                    navigation.replace('Login');
                  }}
                >
                  <Text style={{ fontFamily: fontFamily.bodyBold, color: theme.primary, fontSize: 16 }}>Sair</Text>
                </Pressable>
              ),
            })}
          />
          <Stack.Screen name="CareChain" component={CareChainScreen} options={{ title: 'Care-Chain' }} />
          <Stack.Screen name="Medications" component={MedicationsScreen} options={{ title: 'Medicamentos' }} />
          <Stack.Screen name="EmergencyAlert" component={EmergencyAlertScreen} options={{ title: 'Pedido de ajuda' }} />
        </Stack.Navigator>
      </NavigationContainer>
    </View>
  );
}
