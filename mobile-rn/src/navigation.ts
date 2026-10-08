import type { NativeStackScreenProps } from '@react-navigation/native-stack';

/** Rotas do app e os parâmetros que cada uma recebe. */
export type RootStackParamList = {
  Login: undefined;
  Dashboard: undefined;
  CareChain: { homeId: string; scoreId: string };
  Medications: { homeId: string; patientFirstName: string };
  /** Aberta pelo toque no aviso de SOS: endereço e coordenadas vêm do `data` do push. */
  EmergencyAlert: {
    emergencyId: string;
    homeId?: string;
    address?: string;
    lat?: number;
    lng?: number;
    /** Veio do botão "Estou indo" do aviso: a tela confirma assim que abre. */
    autoAck?: boolean;
  };
};

export type ScreenProps<T extends keyof RootStackParamList> = NativeStackScreenProps<RootStackParamList, T>;
