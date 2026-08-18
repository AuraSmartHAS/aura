import type { NativeStackScreenProps } from '@react-navigation/native-stack';

/** Rotas do app e os parâmetros que cada uma recebe. */
export type RootStackParamList = {
  Login: undefined;
  Dashboard: undefined;
  CareChain: { homeId: string; scoreId: string };
};

export type ScreenProps<T extends keyof RootStackParamList> = NativeStackScreenProps<RootStackParamList, T>;
