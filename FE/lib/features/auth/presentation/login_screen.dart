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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 960;

            final themeToggle = Tooltip(
              message: isDark ? 'Beralih ke Mode Terang' : 'Beralih ke Mode Gelap',
              child: InkWell(
                onTap: () => ref.read(themeProvider.notifier).toggleTheme(),
                borderRadius: BorderRadius.circular(AppRadius.control),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    isDark ? LucideIcons.sun : LucideIcons.moon,
                    color: isDark ? sem.warning : cs.onSurfaceVariant,
                    size: 16,
                  ),
                ),
              ),
            );

            final signInForm = ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isDesktop) ...[
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: cs.primary,
                              borderRadius: BorderRadius.circular(AppRadius.control),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              LucideIcons.barChart2,
                              color: cs.onPrimary,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Text(
                            'SALES INSENTIF',
                            style: tt.labelMedium?.copyWith(
                              letterSpacing: 1.1,
                              color: cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                    ],

                    Text(
                      'Masuk ke Panel Kerja',
                      style: tt.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Gunakan kredensial internal untuk mengelola target, realisasi, dan perhitungan insentif.',
                      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeOutCubic,
                      child: authState.errorMessage != null
                          ? Padding(
                              key: ValueKey(authState.errorMessage),
                              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: sem.dangerBg,
                                  borderRadius: BorderRadius.circular(AppRadius.control),
                                  border: Border.all(
                                    color: sem.danger.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 1),
                                      child: Icon(
                                        LucideIcons.alertCircle,
                                        color: sem.danger,
                                        size: 15,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
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
                            )
                          : const SizedBox.shrink(),
                    ),

                    Text(
                      'Username atau Email',
                      style: tt.labelMedium?.copyWith(color: sem.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.xs + 2),
                    TextFormField(
                      controller: _usernameController,
                      style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          LucideIcons.user,
                          color: cs.onSurfaceVariant,
                          size: 16,
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 38,
                          minHeight: 38,
                        ),
                        hintText: 'nama.user atau email@company.com',
                        filled: true,
                        fillColor: cs.surface,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Username wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    Text(
                      'Kata Sandi',
                      style: tt.labelMedium?.copyWith(color: sem.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.xs + 2),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          LucideIcons.lock,
                          color: cs.onSurfaceVariant,
                          size: 16,
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 38,
                          minHeight: 38,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                            color: cs.onSurfaceVariant,
                            size: 16,
                          ),
                          tooltip: _obscurePassword ? 'Tampilkan sandi' : 'Sembunyikan sandi',
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                        hintText: 'Masukkan kata sandi',
                        filled: true,
                        fillColor: cs.surface,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Kata sandi wajib diisi';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _handleLogin(),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    SizedBox(
                      height: 42,
                      child: ElevatedButton(
                        onPressed: authState.isLoading ? null : _handleLogin,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: authState.isLoading
                              ? SizedBox(
                                  key: const ValueKey('loading'),
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: cs.onPrimary,
                                  ),
                                )
                              : const Row(
                                  key: ValueKey('idle'),
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Masuk'),
                                    SizedBox(width: AppSpacing.sm),
                                    Icon(LucideIcons.arrowRight, size: 16),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );

            if (!isDesktop) {
              return Stack(
                children: [
                  Positioned(top: AppSpacing.lg, right: AppSpacing.lg, child: themeToggle),
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: signInForm,
                    ),
                  ),
                ],
              );
            }

            return Row(
              children: [
                // Left Editorial / Utilitarian Brand Panel
                Expanded(
                  flex: 5,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      border: Border(right: BorderSide(color: cs.outlineVariant)),
                    ),
                    padding: const EdgeInsets.all(AppSpacing.xxxl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: cs.primary,
                                borderRadius: BorderRadius.circular(AppRadius.control),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                LucideIcons.barChart2,
                                color: cs.onPrimary,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Text(
                              'PT SUSANTI MEGAH  /  SALES INSENTIF',
                              style: tt.labelSmall?.copyWith(
                                letterSpacing: 1.0,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kontrol Target &\nInsentif Distribusi.',
                                style: tt.displayLarge?.copyWith(
                                  fontSize: 34,
                                  height: 1.15,
                                  letterSpacing: -0.8,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Text(
                                'Satu buku besar terpadu untuk target kuota distributor, realisasi SAP, cakupan Active Outlet, dan kalkulasi komisi multi-tier.',
                                style: tt.bodyLarge?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  height: 1.55,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        _buildCapabilityRow(
                          context,
                          index: '01',
                          title: 'Hierarki Distributor → Depo → Area',
                          detail: 'Sell-In Depo (ASM), Sell-Out Area (SPV), dan Active Outlet (Toko)',
                        ),
                        Divider(height: 1, color: cs.outlineVariant),
                        _buildCapabilityRow(
                          context,
                          index: '02',
                          title: 'Mesin Kalkulasi Multi-Skema',
                          detail: 'Evaluasi otomatis Konsumsi, Industri (NOO), dan Cabang Surabaya',
                        ),
                        Divider(height: 1, color: cs.outlineVariant),
                        _buildCapabilityRow(
                          context,
                          index: '03',
                          title: 'Audit Batch & Sinkronisasi SAP',
                          detail: 'Validasi impor Excel, rollback batch, dan rekap siap ekspor',
                        ),
                      ],
                    ),
                  ),
                ),

                // Right Precision Sign-In Workspace
                Expanded(
                  flex: 6,
                  child: Stack(
                    children: [
                      Positioned(top: AppSpacing.xl, right: AppSpacing.xl, child: themeToggle),
                      Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(AppSpacing.xxxl),
                          child: signInForm,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCapabilityRow(
    BuildContext context, {
    required String index,
    required String title,
    required String detail,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30,
            child: Text(
              index,
              style: context.tabularNumStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.titleSmall?.copyWith(color: cs.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
