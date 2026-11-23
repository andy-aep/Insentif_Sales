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
            final isDesktop = constraints.maxWidth >= 920;

            final themeToggle = Tooltip(
              message: isDark ? 'Tema terang' : 'Tema gelap',
              child: InkWell(
                onTap: () => ref.read(themeProvider.notifier).toggleTheme(),
                borderRadius: BorderRadius.circular(AppRadius.control),
                hoverColor: sem.hoverBg,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    isDark ? LucideIcons.sun : LucideIcons.moon,
                    color: isDark ? sem.warning : cs.onSurfaceVariant,
                    size: 17,
                  ),
                ),
              ),
            );

            final signInCard = ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: cs.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sharp 3px Viridian ledger rule
                    Container(height: 3, color: cs.primary),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
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
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: cs.primary,
                                      borderRadius: BorderRadius.circular(AppRadius.control),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      LucideIcons.barChart2,
                                      color: cs.onPrimary,
                                      size: 15,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Text(
                                      'PT SUSANTI MEGAH · INSENTIF',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.monoStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xl),
                            ],

                            Text(
                              'Masuk',
                              style: tt.headlineMedium,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Masukkan akun kerja untuk membuka data periode aktif.',
                              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(height: AppSpacing.xl),

                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 160),
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
                                            color: sem.danger.withValues(alpha: 0.4),
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
                                                  fontWeight: FontWeight.w600,
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
                              'Username atau email',
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
                                  minWidth: 40,
                                  minHeight: 44,
                                ),
                                hintText: 'mis. bayu_spv',
                                filled: true,
                                fillColor: cs.surface,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Isi username atau email.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.lg),

                            Text(
                              'Kata sandi',
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
                                  minWidth: 40,
                                  minHeight: 44,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                                    color: cs.onSurfaceVariant,
                                    size: 16,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 44,
                                    minHeight: 44,
                                  ),
                                  tooltip: _obscurePassword ? 'Tampilkan sandi' : 'Sembunyikan sandi',
                                  onPressed: () {
                                    setState(() => _obscurePassword = !_obscurePassword);
                                  },
                                ),
                                hintText: 'Kata sandi akun',
                                filled: true,
                                fillColor: cs.surface,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Isi kata sandi.';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => _handleLogin(),
                            ),
                            const SizedBox(height: AppSpacing.xl),

                            SizedBox(
                              height: 46,
                              child: ElevatedButton(
                                onPressed: authState.isLoading ? null : _handleLogin,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 160),
                                  child: authState.isLoading
                                      ? Row(
                                          key: const ValueKey('loading'),
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              height: 15,
                                              width: 15,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: sem.textMuted,
                                              ),
                                            ),
                                            const SizedBox(width: AppSpacing.sm),
                                            const Text('Memeriksa akun...'),
                                          ],
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
                      child: signInCard,
                    ),
                  ),
                ],
              );
            }

            return Row(
              children: [
                // Left Editorial Deep Brine Ledger Panel
                Expanded(
                  flex: 5,
                  child: Container(
                    decoration: BoxDecoration(
                      color: sem.heroSurface,
                      border: Border(right: BorderSide(color: sem.heroBorder)),
                    ),
                    padding: const EdgeInsets.all(AppSpacing.xxxl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: sem.heroAccent,
                                borderRadius: BorderRadius.circular(AppRadius.control),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                LucideIcons.barChart2,
                                color: sem.heroSurface,
                                size: 15,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                'PT SUSANTI MEGAH · DISTRIBUSI & INSENTIF',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.monoStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.7,
                                  color: sem.heroMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rekap kuota, tonase, dan insentif sales dalam satu buku kerja.',
                                style: tt.displayLarge?.copyWith(
                                  fontSize: 32,
                                  height: 1.18,
                                  letterSpacing: -0.75,
                                  color: sem.heroOnSurface,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(AppRadius.card),
                                  border: Border.all(color: sem.heroBorder),
                                ),
                                child: Column(
                                  children: [
                                    _buildSchemeNoteRow(
                                      context,
                                      scheme: 'Konsumsi',
                                      detail: 'Sell-In Depo (ASM), Sell-Out Area (SPV), Active Outlet (Toko)',
                                    ),
                                    Divider(height: 1, color: sem.heroBorder),
                                    _buildSchemeNoteRow(
                                      context,
                                      scheme: 'Industri',
                                      detail: 'Tonase kontrak (Kg) & pembukaan toko baru (NOO)',
                                    ),
                                    Divider(height: 1, color: sem.heroBorder),
                                    _buildSchemeNoteRow(
                                      context,
                                      scheme: 'Surabaya',
                                      detail: 'Evaluasi kuota langsung TO, SM, dan koordinasi ASC',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Divider(height: 1, color: sem.heroBorder),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Data realisasi tersinkron dengan faktur SAP & upload batch bulanan.',
                          style: tt.bodySmall?.copyWith(
                            color: sem.heroMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Right Warm Alabaster Sign-In Workspace
                Expanded(
                  flex: 6,
                  child: Stack(
                    children: [
                      Positioned(top: AppSpacing.xl, right: AppSpacing.xl, child: themeToggle),
                      Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(AppSpacing.xxxl),
                          child: signInCard,
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

  Widget _buildSchemeNoteRow(
    BuildContext context, {
    required String scheme,
    required String detail,
  }) {
    final sem = context.semantic;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              scheme,
              style: context.monoStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: sem.heroAccent,
              ),
            ),
          ),
          Expanded(
            child: Text(
              detail,
              style: tt.bodySmall?.copyWith(
                color: sem.heroOnSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
