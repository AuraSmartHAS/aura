import React, { useState } from 'react';
import {
  ActivityIndicator,
  Button,
  Image,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native';
import { api, setToken } from '../api';
import type { ScreenProps } from '../navigation';
import { theme } from '../theme';

type Props = ScreenProps<'Login'>;

/** Entrada do app: componente funcional com View, Text, Image e Button. */
export default function LoginScreen({ navigation }: Props) {
  const [email, setEmail] = useState('ana@aura.com');
  const [password, setPassword] = useState('aura1234');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleLogin() {
    setLoading(true);
    setError(null);
    try {
      const session = await api.login(email, password);
      setToken(session.token);
      navigation.replace('Dashboard');
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Não foi possível entrar.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <View style={styles.container}>
      <Image source={require('../../assets/aura-logo.png')} style={styles.logo} accessibilityLabel="Logo AURA" />

      <Text style={styles.title}>AURA Care-Chain</Text>
      <Text style={styles.subtitle}>Cuidado domiciliar com cadeia de segurança</Text>

      <View style={styles.card}>
        <Text style={styles.label}>E-mail</Text>
        <TextInput
          style={styles.input}
          value={email}
          onChangeText={setEmail}
          autoCapitalize="none"
          keyboardType="email-address"
          placeholder="ana@aura.com"
          placeholderTextColor={theme.muted}
          accessibilityLabel="Campo de e-mail"
        />

        <Text style={styles.label}>Senha</Text>
        <TextInput
          style={styles.input}
          value={password}
          onChangeText={setPassword}
          secureTextEntry
          placeholder="••••••••"
          placeholderTextColor={theme.muted}
          accessibilityLabel="Campo de senha"
        />

        {error !== null && <Text style={styles.error}>{error}</Text>}

        {loading ? (
          <ActivityIndicator color={theme.accent} style={styles.loader} />
        ) : (
          <View style={styles.button}>
            <Button title="Entrar" color={theme.accent} onPress={handleLogin} />
          </View>
        )}

        <TouchableOpacity onPress={() => { setEmail('admin@aura.com'); setPassword('aura1234'); }}>
          <Text style={styles.hint}>usar conta da Torre de Controle</Text>
        </TouchableOpacity>
      </View>

      <Text style={styles.footer}>Smart HAS · Enterprise Challenge 2026 · FIAP</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: theme.bg, alignItems: 'center', justifyContent: 'center', padding: 24 },
  logo: { width: 108, height: 108, borderRadius: 24 },
  title: { color: theme.textStrong, fontSize: 26, fontWeight: '700', marginTop: 16 },
  subtitle: { color: theme.muted, fontSize: 14, marginTop: 4, textAlign: 'center' },
  card: {
    width: '100%',
    maxWidth: 380,
    backgroundColor: theme.surface,
    borderColor: theme.border,
    borderWidth: 1,
    borderRadius: 14,
    padding: 20,
    marginTop: 24,
  },
  label: { color: theme.muted, fontSize: 12, marginBottom: 4, marginTop: 12 },
  input: {
    backgroundColor: theme.bg,
    borderColor: theme.border,
    borderWidth: 1,
    borderRadius: 8,
    color: theme.text,
    fontSize: 16,
    paddingHorizontal: 12,
    paddingVertical: 12,
  },
  button: { marginTop: 20 },
  loader: { marginTop: 24 },
  error: { color: theme.danger, marginTop: 12, fontSize: 13 },
  hint: { color: theme.info, fontSize: 12, marginTop: 16, textAlign: 'center' },
  footer: { color: theme.muted, fontSize: 11, marginTop: 28 },
});
