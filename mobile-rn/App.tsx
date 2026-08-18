import { NavigationContainer, DarkTheme } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { StatusBar } from 'expo-status-bar';
import React from 'react';
import CareChainScreen from './src/screens/CareChainScreen';
import DashboardScreen from './src/screens/DashboardScreen';
import LoginScreen from './src/screens/LoginScreen';
import type { RootStackParamList } from './src/navigation';
import { theme } from './src/theme';

const Stack = createNativeStackNavigator<RootStackParamList>();

const navigationTheme = {
  ...DarkTheme,
  colors: {
    ...DarkTheme.colors,
    background: theme.bg,
    card: theme.surface,
    text: theme.textStrong,
    border: theme.border,
    primary: theme.accent,
  },
};

/** Navegação entre telas com React Navigation (native stack). */
export default function App() {
  return (
    <NavigationContainer theme={navigationTheme}>
      <StatusBar style="light" />
      <Stack.Navigator
        initialRouteName="Login"
        screenOptions={{
          headerStyle: { backgroundColor: theme.surface },
          headerTintColor: theme.textStrong,
          contentStyle: { backgroundColor: theme.bg },
        }}
      >
        <Stack.Screen name="Login" component={LoginScreen} options={{ headerShown: false }} />
        <Stack.Screen name="Dashboard" component={DashboardScreen} options={{ title: 'Painel da cuidadora' }} />
        <Stack.Screen name="CareChain" component={CareChainScreen} options={{ title: 'Care-Chain' }} />
      </Stack.Navigator>
    </NavigationContainer>
  );
}
