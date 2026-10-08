import { createNavigationContainerRef } from '@react-navigation/native';
import Constants, { ExecutionEnvironment } from 'expo-constants';
import type * as NotificationsModule from 'expo-notifications';
import { Platform } from 'react-native';
import { api, hasSession, isPatient } from './api';
import type { RootStackParamList } from './navigation';
import { ACK_ACTION, isSos, PendingDeepLink, PUSH_CHANNELS, PushDestination, SOS_ACK_CATEGORY } from './pushRouting';

/**
 * Push de ponta a ponta no app RN: canais, permissão, ciclo de vida do token FCM, aviso com o app
 * aberto e o deep link do toque. Só no Android com build próprio (dev build ou APK): no navegador
 * da demo, no iOS (sem chave APNs) e no Expo Go tudo aqui vira no-op e o app segue igual.
 *
 * O Expo Go do SDK 53+ derruba o app no simples `import` do expo-notifications no Android, por
 * isso o módulo só é carregado (require) depois de saber que não é o Expo Go.
 */
const enabled =
  Platform.OS === 'android' && Constants.executionEnvironment !== ExecutionEnvironment.StoreClient;

// eslint-disable-next-line @typescript-eslint/no-require-imports
const Notifications: typeof NotificationsModule = enabled ? require('expo-notifications') : (null as never);

export const navigationRef = createNavigationContainerRef<RootStackParamList>();

function go(destination: PushDestination): void {
  if (isPatient() || !navigationRef.isReady()) return;
  if (destination.name === 'EmergencyAlert') {
    navigationRef.navigate('EmergencyAlert', destination.params);
  } else {
    navigationRef.navigate('Dashboard');
  }
}

export const pendingDeepLink = new PendingDeepLink(hasSession, go);

/** `data` do aviso tocado. Aviso desenhado pelo sistema (app em segundo plano) traz o `data` do FCM
 *  em `trigger.remoteMessage`; o exibido com o app aberto, em `content.data`. */
function dataOf(response: NotificationsModule.NotificationResponse): Record<string, unknown> {
  const request = response.notification.request;
  const remote = (request.trigger as { remoteMessage?: { data?: Record<string, string> } } | null)?.remoteMessage;
  return { ...(request.content.data ?? {}), ...(remote?.data ?? {}) };
}

let started = false;

export async function initPush(): Promise<void> {
  if (!enabled || started) return;
  started = true;

  // com o app aberto o Android não desenha o aviso do FCM: é este handler que manda exibir
  Notifications.setNotificationHandler({
    handleNotification: async (notification) => {
      const sos = isSos(notification.request.content.data?.kind);
      return {
        shouldShowBanner: true,
        shouldShowList: true,
        shouldPlaySound: true,
        shouldSetBadge: false,
        priority: sos ? Notifications.AndroidNotificationPriority.MAX : Notifications.AndroidNotificationPriority.HIGH,
      };
    },
  });

  await Notifications.setNotificationChannelAsync(PUSH_CHANNELS.sos.id, {
    name: PUSH_CHANNELS.sos.name,
    description: PUSH_CHANNELS.sos.description,
    importance: Notifications.AndroidImportance.MAX,
    sound: 'default',
    vibrationPattern: [0, 500, 250, 500],
    lockscreenVisibility: Notifications.AndroidNotificationVisibility.PUBLIC,
  });
  await Notifications.setNotificationChannelAsync(PUSH_CHANNELS.geral.id, {
    name: PUSH_CHANNELS.geral.name,
    description: PUSH_CHANNELS.geral.description,
    importance: Notifications.AndroidImportance.HIGH,
  });

  // o SOS chega só com dados e com esta categoria: é ela que põe o botão no aviso. Abre o app
  // porque a sessão do RN vive na memória — com o app encerrado não haveria com que confirmar.
  await Notifications.setNotificationCategoryAsync(SOS_ACK_CATEGORY, [
    { identifier: ACK_ACTION, buttonTitle: 'Estou indo', options: { opensAppToForeground: true } },
  ]);

  Notifications.addPushTokenListener((token) => {
    if (hasSession()) api.registerPushToken(String(token.data)).catch(() => undefined);
  });
  Notifications.addNotificationResponseReceivedListener((response) =>
    pendingDeepLink.open(dataOf(response), response.actionIdentifier === ACK_ACTION),
  );

  // toque que abriu o app encerrado
  const last = await Notifications.getLastNotificationResponseAsync();
  if (last) {
    pendingDeepLink.open(dataOf(last), last.actionIdentifier === ACK_ACTION);
    await Notifications.clearLastNotificationResponseAsync();
  }
}

/** Login: pede a permissão (prompt do Android 13+) e registra o aparelho. Melhor esforço. */
export async function registerPushToken(): Promise<void> {
  if (!enabled || !hasSession()) return;
  try {
    const { granted } = await Notifications.requestPermissionsAsync();
    if (!granted) return;
    const token = await Notifications.getDevicePushTokenAsync();
    await api.registerPushToken(String(token.data));
  } catch {
    // sem Firebase configurado (build sem google-services.json) o app segue sem push
  }
}

/** Logout: roda com a sessão ainda viva (o DELETE é autenticado) e nunca segura a saída. */
export async function unregisterPushToken(): Promise<void> {
  pendingDeepLink.clear();
  if (!enabled) return;
  let token: string | null = null;
  try {
    token = String((await Notifications.getDevicePushTokenAsync()).data);
  } catch {
    token = null;
  }
  try {
    await api.unregisterPushToken(token);
  } catch {
    // sem rede: o servidor ainda tem o token, mas o login de outra pessoa no aparelho o transfere
  }
}
