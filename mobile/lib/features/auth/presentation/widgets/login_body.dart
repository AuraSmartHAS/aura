import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../bloc/auth_bloc.dart';

class LoginBody extends StatefulWidget {
  const LoginBody({super.key});

  @override
  State<LoginBody> createState() => _LoginBodyState();
}

class _LoginBodyState extends State<LoginBody> {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onForgotPassword() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Recuperação de senha em breve')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.lg,
              vertical: AppDimensions.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Branded header (typographic lockup, no logo asset) ──
                const _AuraWordmark(tagline: 'Cuidado em casa, com calma e clareza.'),
                const SizedBox(height: AppDimensions.xxl),
                Text('Entrar', style: textTheme.displaySmall),
                const SizedBox(height: AppDimensions.xs),
                Text(
                  'Bom te ver de novo.',
                  style: textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppDimensions.xl),

                // ── E-mail ──────────────────────────────────────────────
                Text('E-mail', style: textTheme.labelLarge),
                const SizedBox(height: AppDimensions.sm),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'Seu e-mail'),
                ),
                const SizedBox(height: AppDimensions.md),

                // ── Senha ───────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('Senha', style: textTheme.labelLarge),
                    TextButton(
                      onPressed: _onForgotPassword,
                      child: const Text('Esqueci minha senha'),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.sm),
                TextField(
                  controller: _passwordController,
                  obscureText: !_passwordVisible,
                  decoration: InputDecoration(
                    hintText: 'Sua senha',
                    suffixIcon: IconButton(
                      tooltip: _passwordVisible
                          ? 'Ocultar senha'
                          : 'Mostrar senha',
                      icon: Icon(
                        _passwordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _passwordVisible = !_passwordVisible;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.lg),

                // ── Inline error ────────────────────────────────────────
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    if (state is AuthFailure) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppDimensions.md),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: AppDimensions.lg,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: AppDimensions.sm),
                            Expanded(
                              child: Text(
                                state.message,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                // ── Submit ──────────────────────────────────────────────
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    final isLoading = state is AuthLoading;
                    return SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: isLoading
                            ? null
                            : () {
                                context.read<AuthBloc>().add(
                                      LoginEvent(
                                        _emailController.text,
                                        _passwordController.text,
                                      ),
                                    );
                              },
                        child: isLoading
                            ? const SizedBox(
                                width: AppDimensions.lg,
                                height: AppDimensions.lg,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Entrar'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppDimensions.lg),

                // ── Switch to signup ────────────────────────────────────
                Center(
                  child: TextButton(
                    onPressed: () => context.push(AppRoutes.signup),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Não tem uma conta? ',
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          TextSpan(
                            text: 'Criar conta',
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppColors.link,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Typographic brand lockup used across the auth screens. No logo asset is
/// available, so the wordmark leans on the display (Bricolage Grotesque) voice
/// plus a short, warm tagline — a real header, not a bare letterspaced label.
class _AuraWordmark extends StatelessWidget {
  const _AuraWordmark({required this.tagline});

  final String tagline;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      header: true,
      label: 'AURA. $tagline',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AURA',
            style: textTheme.displayLarge?.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: AppDimensions.xs),
          Container(
            width: AppDimensions.xxl,
            height: AppDimensions.xs,
            decoration: BoxDecoration(
              color: AppColors.careGreen,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          Text(
            tagline,
            style: textTheme.titleMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
