import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isDark = context.isDarkMode;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sem = context.semantic;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Top-right Theme Toggle
          Positioned(
            top: 24,
            right: 24,
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outlineVariant),
                boxShadow: context.colors.cardShadows,
              ),
              child: IconButton(
                icon: Icon(
                  isDark ? LucideIcons.sun : LucideIcons.moon,
                  color: isDark ? sem.warning : cs.onSurfaceVariant,
                  size: 18,
                ),
                tooltip: isDark ? 'Mode Terang' : 'Mode Gelap',
                onPressed: () {
                  ref.read(themeProvider.notifier).toggleTheme();
                },
              ),
            ),
          ),

          // Main Center Card
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant),
                  boxShadow: context.colors.cardShadows,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Brand Icon
                        Center(
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: cs.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              LucideIcons.layoutGrid,
                              color: cs.onPrimary,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Title & Subtitle
                        Text(
                          'Sales Insentif',
                          textAlign: TextAlign.center,
                          style: tt.headlineMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Masuk untuk mengelola target dan insentif penjualan',
                          textAlign: TextAlign.center,
                          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 28),

                        // Error Banner
                        if (authState.errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: sem.dangerBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: sem.danger.withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              children: [
                                Icon(LucideIcons.alertCircle, color: sem.danger, size: 17),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    authState.errorMessage!,
                                    style: tt.bodySmall?.copyWith(
                                      color: sem.danger,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],

                        // Username Field
                        Text(
                          'Username atau Email',
                          style: tt.labelLarge?.copyWith(color: sem.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _usernameController,
                          style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                          decoration: InputDecoration(
                            prefixIcon: Icon(LucideIcons.user, color: cs.onSurfaceVariant, size: 17),
                            hintText: 'Masukkan username / email...',
                            filled: true,
                            fillColor: sem.subtleBg,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Username wajib diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        // Password Field
                        Text(
                          'Kata Sandi',
                          style: tt.labelLarge?.copyWith(color: sem.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                          decoration: InputDecoration(
                            prefixIcon: Icon(LucideIcons.lock, color: cs.onSurfaceVariant, size: 17),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                                color: cs.onSurfaceVariant,
                                size: 17,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            hintText: '••••••••',
                            filled: true,
                            fillColor: sem.subtleBg,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Kata sandi wajib diisi';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _handleLogin(),
                        ),
                        const SizedBox(height: 24),

                        // Submit Button
                        SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            onPressed: authState.isLoading ? null : _handleLogin,
                            child: authState.isLoading
                                ? SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: cs.onPrimary,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('Masuk'),
                                      SizedBox(width: 8),
                                      Icon(LucideIcons.arrowRight, size: 17),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
