import React, { useEffect, useState } from 'react';
import { Image, StyleSheet, Text, TextInput, TouchableOpacity, View } from 'react-native';
import { api, isPatient, setRole, setToken } from '../api';
import { pendingDeepLink, registerPushToken } from '../push';
import AuraButton from '../components/AuraButton';
import type { ScreenProps } from '../navigation';
import { fontFamily, radius, spacing, theme } from '../theme';

type Props = ScreenProps<'Login'>;

/** Entrada do app: componente funcional com View, Text, Image e Button. */
export default function LoginScreen({ navigation }: Props) {
  const [email, setEmail] = useState('ana@aura.com');
  const [password, setPassword] = useState('aura1234');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Entrar no login é sair da sessão: um token vencido que sobrasse na memória faria uma senha
  // errada aparecer como "sua sessão expirou".
  useEffect(() => {
    setToken(null);
    setRole(null);
  }, []);

  async function handleLogin() {
    setLoading(true);
    setError(null);
    try {
      const session = await api.login(email, password);
      setToken(session.token);
      setRole(session.role);
      // o aparelho passa a ser desta pessoa: o servidor o tira de quem entrou antes
      registerPushToken();
      navigation.replace('Dashboard');
      // toque num aviso que chegou antes do login: abre agora, com sessão
      const destination = pendingDeepLink.take();
      if (destination?.name === 'EmergencyAlert' && !isPatient()) navigation.navigate('EmergencyAlert', destination.params);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Não foi possível entrar.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <View style={styles.container}>
      <Image source={require('../../assets/aura-logo.png')} style={styles.logo} accessibilityLabel="Logo AURA" />

      <Text style={styles.title}>AURA</Text>
      <Text style={styles.subtitle}>Cuidado em casa, com calma e clareza.</Text>

      <View style={styles.card}>
        <Text style={styles.label}>E-mail</Text>
        <TextInput
          style={styles.input}
          value={email}
          onChangeText={setEmail}
          autoCapitalize="none"
          keyboardType="email-address"
          placeholder="ana@aura.com"
          placeholderTextColor={theme.hint}
          accessibilityLabel="Campo de e-mail"
        />

        <Text style={styles.label}>Senha</Text>
        <TextInput
          style={styles.input}
          value={password}
          onChangeText={setPassword}
          secureTextEntry
          placeholder="••••••••"
          placeholderTextColor={theme.hint}
          accessibilityLabel="Campo de senha"
        />

        {error !== null && <Text style={styles.error}>{error}</Text>}

        <View style={styles.button}>
          <AuraButton title="Entrar" onPress={handleLogin} loading={loading} />
        </View>

        <TouchableOpacity onPress={() => { setEmail('admin@aura.com'); setPassword('aura1234'); }}>
          <Text style={styles.hint}>Usar conta da Operação</Text>
        </TouchableOpacity>
      </View>

      <Text style={styles.footer}>Smart HAS · Enterprise Challenge 2026 · FIAP</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: theme.bg, alignItems: 'center', justifyContent: 'center', padding: spacing.lg },
  logo: { width: 108, height: 108, borderRadius: radius.lg },
  title: { color: theme.ink, fontSize: 26, fontFamily: fontFamily.display, marginTop: spacing.md },
  subtitle: { color: theme.text, fontSize: 14, marginTop: spacing.xs, textAlign: 'center', fontFamily: fontFamily.body },
  card: {
    width: '100%',
    maxWidth: 380,
    backgroundColor: theme.surface,
    borderColor: theme.border,
    borderWidth: 1,
    borderRadius: radius.lg,
    padding: spacing.md,
    marginTop: spacing.lg,
  },
  label: { color: theme.text, fontSize: 12, marginBottom: spacing.xs, marginTop: spacing.md, fontFamily: fontFamily.bodyBold },
  input: {
    backgroundColor: theme.surface,
    borderColor: theme.border,
    borderWidth: 1,
    borderRadius: radius.md,
    color: theme.textStrong,
    fontSize: 16,
    fontFamily: fontFamily.body,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm + 4,
  },
  button: { marginTop: spacing.lg },
  error: { color: theme.danger, marginTop: spacing.md, fontSize: 13, fontFamily: fontFamily.body },
  hint: { color: theme.primary, fontSize: 12, marginTop: spacing.md, textAlign: 'center', fontFamily: fontFamily.bodyBold },
  footer: { color: theme.muted, fontSize: 11, marginTop: spacing.xl - 4, fontFamily: fontFamily.body },
});
