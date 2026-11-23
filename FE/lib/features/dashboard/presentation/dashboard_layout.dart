import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/providers/auth_provider.dart';

class NavItemData {
  final String title;
  final String route;
  final IconData icon;
  final String? permissionKey;
  final String group;

  const NavItemData({
    required this.title,
    required this.route,
    required this.icon,
    this.permissionKey,
    required this.group,
  });
}

class DashboardLayout extends ConsumerStatefulWidget {
  final Widget child;

  const DashboardLayout({super.key, required this.child});

  @override
  ConsumerState<DashboardLayout> createState() => _DashboardLayoutState();
}

class _DashboardLayoutState extends ConsumerState<DashboardLayout> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _sidebarExpanded = true;

  final List<NavItemData> _allNavItems = const [
    NavItemData(
      title: 'Dashboard',
      route: '/dashboard',
      icon: LucideIcons.layoutGrid,
      group: 'OPERASIONAL',
    ),
    NavItemData(
      title: 'Master Distributor',
      route: '/master/distributor',
      icon: LucideIcons.building2,
      group: 'OPERASIONAL',
    ),
    NavItemData(
      title: 'Master Target Kuota',
      route: '/master/target',
      icon: LucideIcons.target,
      group: 'OPERASIONAL',
    ),
    NavItemData(
      title: 'Realisasi Penjualan',
      route: '/master/realisasi',
      icon: LucideIcons.shoppingBag,
      group: 'OPERASIONAL',
    ),
    NavItemData(
      title: 'Tim & Area Sales',
      route: '/master/surabaya',
      icon: LucideIcons.users,
      group: 'OPERASIONAL',
    ),
    NavItemData(
      title: 'Insentif Distributor',
      route: '/incentives/distributor',
      icon: LucideIcons.coins,
      group: 'PERHITUNGAN',
    ),
    NavItemData(
      title: 'Insentif Industri',
      route: '/incentives/industri',
      icon: LucideIcons.factory,
      group: 'PERHITUNGAN',
    ),
    NavItemData(
      title: 'Insentif Surabaya',
      route: '/incentives/surabaya',
      icon: LucideIcons.landmark,
      group: 'PERHITUNGAN',
    ),
    NavItemData(
      title: 'Skema & Bobot',
      route: '/settings/incentives',
      icon: LucideIcons.sliders,
      group: 'PENGATURAN',
    ),
    NavItemData(
      title: 'Bulk Upload Data',
      route: '/bulk-upload',
      icon: LucideIcons.uploadCloud,
      group: 'PENGATURAN',
    ),
    NavItemData(
      title: 'Pengguna & Akses',
      route: '/users',
      icon: LucideIcons.shield,
      group: 'PENGATURAN',
    ),
  ];

  bool _isItemAllowed(NavItemData item, dynamic role) {
    if (role == null) return false;
    final roleName = (role.name ?? '').toString().trim().toLowerCase();
    if (roleName == 'administrator' || roleName == 'superadmin' || roleName == 'admin') {
      return true;
    }

    final menuPermissions = role.menuPermissions as List?;
    if (menuPermissions == null || menuPermissions.isEmpty) {
      return item.route == '/dashboard';
    }

    final routeLower = item.route.toLowerCase();
    // 1. Prioritaskan exact route match agar setting hak akses per-menu akurat 1-to-1
    for (final perm in menuPermissions) {
      final menuRoute = (perm.menu?.route ?? '').toString().trim().toLowerCase();
      if (menuRoute.isNotEmpty && routeLower == menuRoute) {
        return perm.canView == true;
      }
    }
    // 2. Fallback untuk kompatibilitas route grup lama (/master, /incentives/calculate)
    for (final perm in menuPermissions) {
      final menuRoute = (perm.menu?.route ?? '').toString().trim().toLowerCase();
      if (menuRoute == '/master' && routeLower.startsWith('/master')) {
        return perm.canView == true;
      }
      if (menuRoute == '/incentives/calculate' && routeLower.startsWith('/incentives')) {
        return perm.canView == true;
      }
    }
    return false;
  }

  NavItemData? _findActiveNavItem(List<NavItemData> items, String currentRoute) {
    for (final item in items) {
      if (currentRoute == item.route ||
          (item.route != '/dashboard' && currentRoute.startsWith(item.route))) {
        return item;
      }
    }
    return null;
  }

  void _showQuickJumpDialog(List<NavItemData> items) {
    showDialog(
      context: context,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final cs = Theme.of(ctx).colorScheme;
            final tt = Theme.of(ctx).textTheme;
            final sem = ctx.semantic;
            final filtered = items
                .where((i) =>
                    i.title.toLowerCase().contains(query.toLowerCase()) ||
                    i.group.toLowerCase().contains(query.toLowerCase()))
                .toList();
            return Dialog(
              backgroundColor: cs.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.card),
                side: BorderSide(color: cs.outlineVariant),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460, maxHeight: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: TextField(
                        autofocus: true,
                        onChanged: (v) => setDialogState(() => query = v),
                        onSubmitted: (_) {
                          if (filtered.isNotEmpty) {
                            Navigator.pop(ctx);
                            context.go(filtered.first.route);
                          }
                        },
                        style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Ketik nama halaman...',
                          prefixIcon: const Icon(LucideIcons.search, size: 16),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 38,
                            minHeight: 44,
                          ),
                          filled: true,
                          fillColor: sem.subtleBg,
                        ),
                      ),
                    ),
                    Divider(height: 1, color: cs.outlineVariant),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'Halaman tidak ditemukan.',
                                style: tt.bodySmall,
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 2),
                              itemBuilder: (_, idx) {
                                final item = filtered[idx];
                                return Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(AppRadius.control),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(AppRadius.control),
                                    hoverColor: sem.hoverBg,
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      context.go(item.route);
                                    },
                                    child: SizedBox(
                                      height: 44,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                                        child: Row(
                                          children: [
                                            Icon(item.icon, size: 16, color: cs.primary),
                                            const SizedBox(width: AppSpacing.md),
                                            Expanded(
                                              child: Text(
                                                item.title,
                                                style: tt.titleSmall,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              item.group,
                                              style: ctx.monoStyle(
                                                fontSize: 10,
                                                color: sem.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showChangeOwnPasswordDialog() {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final cs = Theme.of(context).colorScheme;
          final tt = Theme.of(context).textTheme;
          final sem = context.semantic;

          return AlertDialog(
            backgroundColor: cs.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              side: BorderSide(color: cs.outlineVariant),
            ),
            title: Row(
              children: [
                Icon(LucideIcons.key, color: cs.primary, size: 18),
                const SizedBox(width: AppSpacing.md),
                Text(
                  'Ubah kata sandi',
                  style: tt.titleLarge,
                ),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (errorText != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: sem.dangerBg,
                        borderRadius: BorderRadius.circular(AppRadius.control),
                        border: Border.all(color: sem.danger.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.alertCircle, color: sem.danger, size: 16),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              errorText!,
                              style: tt.bodySmall?.copyWith(color: sem.danger, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  TextField(
                    controller: currentPassCtrl,
                    obscureText: obscureCurrent,
                    style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Kata sandi lama',
                      suffixIcon: IconButton(
                        icon: Icon(obscureCurrent ? LucideIcons.eyeOff : LucideIcons.eye, size: 17),
                        onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: newPassCtrl,
                    obscureText: obscureNew,
                    style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Kata sandi baru',
                      hintText: 'Minimal 6 karakter',
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? LucideIcons.eyeOff : LucideIcons.eye, size: 17),
                        onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: confirmPassCtrl,
                    obscureText: obscureConfirm,
                    style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Ulangi kata sandi baru',
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? LucideIcons.eyeOff : LucideIcons.eye, size: 17),
                        onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Batal', style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final curr = currentPassCtrl.text.trim();
                  final nw = newPassCtrl.text.trim();
                  final conf = confirmPassCtrl.text.trim();

                  if (curr.isEmpty) {
                    setDialogState(() => errorText = 'Isi kata sandi lama.');
                    return;
                  }
                  if (nw.length < 6) {
                    setDialogState(() => errorText = 'Kata sandi baru minimal 6 karakter.');
                    return;
                  }
                  if (nw != conf) {
                    setDialogState(() => errorText = 'Konfirmasi kata sandi tidak sama.');
                    return;
                  }

                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final nav = Navigator.of(ctx);
                  final msg = await ref.read(authProvider.notifier).changeOwnPassword(curr, nw);
                  final isSuccess = msg?.contains('berhasil') == true;
                  if (!ctx.mounted) return;
                  if (isSuccess) {
                    nav.pop();
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: const Text('Kata sandi tersimpan.'),
                        backgroundColor: sem.successSolid,
                      ),
                    );
                  } else {
                    setDialogState(() => errorText = msg ?? 'Gagal menyimpan kata sandi.');
                  }
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showProfileDialog() {
    final authState = ref.read(authProvider);
    final user = authState.user;

    showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;
        final sem = ctx.semantic;

        return AlertDialog(
          backgroundColor: cs.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            side: BorderSide(color: cs.outlineVariant),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
                ),
                alignment: Alignment.center,
                child: Text(
                  (user?.name.isNotEmpty == true ? user!.name[0] : 'U').toUpperCase(),
                  style: tt.titleMedium?.copyWith(color: cs.onPrimaryContainer),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? 'Pengguna',
                      style: tt.titleMedium,
                    ),
                    Text(
                      '@${user?.username ?? '-'} · ${user?.role?.displayName ?? 'User'}',
                      style: tt.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(height: 24),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: sem.subtleBg,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      _buildProfileRow(ctx, 'Posisi', user?.position?.name ?? 'Tanpa posisi'),
                      const SizedBox(height: AppSpacing.sm),
                      _buildProfileRow(ctx, 'Email', user?.email ?? '-'),
                      const SizedBox(height: AppSpacing.sm),
                      _buildProfileRow(ctx, 'Role akses', user?.role?.displayName ?? '-'),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.primary,
                    side: BorderSide(color: cs.primary.withValues(alpha: 0.45)),
                  ),
                  icon: const Icon(LucideIcons.key, size: 15),
                  label: const Text('Ubah kata sandi'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showChangeOwnPasswordDialog();
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sem.dangerBg,
                    foregroundColor: sem.danger,
                    elevation: 0,
                  ),
                  icon: const Icon(LucideIcons.logOut, size: 15),
                  label: const Text('Keluar akun'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showLogoutDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileRow(BuildContext context, String label, String value) {
    final tt = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: tt.bodySmall),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: tt.labelLarge?.copyWith(fontSize: 12.5),
          ),
        ),
      ],
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;
        final sem = ctx.semantic;

        return AlertDialog(
          backgroundColor: cs.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            side: BorderSide(color: cs.outlineVariant),
          ),
          title: Row(
            children: [
              Icon(LucideIcons.logOut, color: sem.danger, size: 18),
              const SizedBox(width: AppSpacing.md),
              Text('Keluar dari akun?', style: tt.titleLarge),
            ],
          ),
          content: Text(
            'Sesi kerja saat ini akan ditutup.',
            style: tt.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Batal', style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(authProvider.notifier).logout();
                context.go('/login');
              },
              child: const Text('Keluar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.toString();
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final showExpandedSidebar = isDesktop && _sidebarExpanded;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sem = context.semantic;
    final isDark = context.isDarkMode;

    final visibleNavItems = _allNavItems.where((item) {
      return _isItemAllowed(item, user?.role);
    }).toList();
    final activeNav = _findActiveNavItem(visibleNavItems, currentRoute);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            _showQuickJumpDialog(visibleNavItems),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
            _showQuickJumpDialog(visibleNavItems),
      },
      child: Focus(
        autofocus: false,
        child: Scaffold(
          key: _scaffoldKey,
          drawer: !isDesktop ? _buildMobileDrawer(context, visibleNavItems, currentRoute) : null,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: Row(
              children: [
                // Left Navigation Ledger Sidebar
                if (isDesktop)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: showExpandedSidebar ? 240 : 68,
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color: cs.surface,
                      border: Border(right: BorderSide(color: cs.outlineVariant)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Brand Header
                        Container(
                          height: 58,
                          padding: EdgeInsets.symmetric(
                            horizontal: showExpandedSidebar ? AppSpacing.lg : AppSpacing.md,
                          ),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: cs.outlineVariant)),
                          ),
                          child: Row(
                            mainAxisAlignment: showExpandedSidebar
                                ? MainAxisAlignment.start
                                : MainAxisAlignment.center,
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
                              if (showExpandedSidebar) ...[
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Sales Insentif',
                                    style: tt.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    LucideIcons.panelLeftClose,
                                    size: 16,
                                    color: cs.onSurfaceVariant,
                                  ),
                                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                  tooltip: 'Tutup sidebar',
                                  onPressed: () => setState(() => _sidebarExpanded = false),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Grouped Navigation Items
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm + 2,
                              vertical: AppSpacing.md,
                            ),
                            children: _buildGroupedSidebarItems(
                              context,
                              visibleNavItems,
                              currentRoute,
                              showExpandedSidebar,
                            ),
                          ),
                        ),

                        // Bottom Footer Actions
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm + 2),
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: cs.outlineVariant)),
                          ),
                          child: Column(
                            children: [
                              if (!showExpandedSidebar) ...[
                                IconButton(
                                  icon: Icon(
                                    LucideIcons.panelLeftOpen,
                                    size: 16,
                                    color: cs.onSurfaceVariant,
                                  ),
                                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                                  tooltip: 'Buka sidebar',
                                  onPressed: () => setState(() => _sidebarExpanded = true),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                              ],
                              _buildSidebarTile(
                                context: context,
                                title: 'Keluar',
                                icon: LucideIcons.logOut,
                                isSelected: false,
                                showExpanded: showExpandedSidebar,
                                isDanger: true,
                                onTap: _showLogoutDialog,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Right Area: Topbar + Main Canvas
                Expanded(
                  child: Column(
                    children: [
                      // Top Header Strip (58px)
                      Container(
                        height: 58,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          border: Border(bottom: BorderSide(color: cs.outlineVariant)),
                        ),
                        child: Row(
                          children: [
                            if (!isDesktop) ...[
                              IconButton(
                                icon: Icon(LucideIcons.menu, color: cs.onSurface, size: 18),
                                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                                tooltip: 'Buka menu',
                                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                            ],

                            // Active Section Breadcrumb
                            if (activeNav != null && screenWidth >= 820) ...[
                              Text(
                                activeNav.group,
                                style: context.monoStyle(
                                  fontSize: 10.5,
                                  color: sem.textFaint,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                                child: Text(
                                  '/',
                                  style: tt.bodySmall?.copyWith(color: sem.textFaint),
                                ),
                              ),
                              Text(
                                activeNav.title,
                                style: tt.titleSmall?.copyWith(color: cs.onSurface),
                              ),
                              const SizedBox(width: AppSpacing.xl),
                            ],

                            // Quick Command Trigger (Ctrl+K)
                            if (screenWidth >= 560)
                              InkWell(
                                onTap: () => _showQuickJumpDialog(visibleNavItems),
                                borderRadius: BorderRadius.circular(AppRadius.control),
                                hoverColor: sem.hoverBg,
                                child: Container(
                                  width: screenWidth >= 1100 ? 250 : 196,
                                  height: 40,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: sem.subtleBg,
                                    borderRadius: BorderRadius.circular(AppRadius.control),
                                    border: Border.all(color: cs.outlineVariant),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        LucideIcons.search,
                                        size: 14,
                                        color: cs.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Text(
                                          'Loncat ke menu...',
                                          style: tt.bodySmall?.copyWith(fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: cs.surface,
                                          borderRadius: BorderRadius.circular(AppRadius.tag),
                                          border: Border.all(color: cs.outlineVariant),
                                        ),
                                        child: Text(
                                          'Ctrl K',
                                          style: context.monoStyle(
                                            fontSize: 10,
                                            color: sem.textMuted,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            const Spacer(),

                            // Quick Upload Shortcut
                            _buildTopActionButton(
                              context: context,
                              icon: LucideIcons.uploadCloud,
                              tooltip: 'Bulk Upload Data',
                              onTap: () => context.go('/bulk-upload'),
                            ),
                            const SizedBox(width: AppSpacing.sm),

                            // Theme Toggle
                            _buildTopActionButton(
                              context: context,
                              icon: isDark ? LucideIcons.sun : LucideIcons.moon,
                              tooltip: isDark ? 'Tema terang' : 'Tema gelap',
                              iconColor: isDark ? sem.warning : cs.onSurfaceVariant,
                              onTap: () => ref.read(themeProvider.notifier).toggleTheme(),
                            ),
                            const SizedBox(width: AppSpacing.md),

                            Container(
                              width: 1,
                              height: 20,
                              color: cs.outlineVariant,
                            ),
                            const SizedBox(width: AppSpacing.md),

                            // User Profile Button
                            InkWell(
                              onTap: _showProfileDialog,
                              borderRadius: BorderRadius.circular(AppRadius.control),
                              hoverColor: sem.hoverBg,
                              child: SizedBox(
                                height: 44,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: cs.primaryContainer,
                                          borderRadius: BorderRadius.circular(AppRadius.control),
                                          border: Border.all(
                                            color: cs.primary.withValues(alpha: 0.25),
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          (user?.name.isNotEmpty == true ? user!.name[0] : 'A')
                                              .toUpperCase(),
                                          style: tt.labelLarge?.copyWith(
                                            color: cs.onPrimaryContainer,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      if (screenWidth >= 520) ...[
                                        const SizedBox(width: 9),
                                        ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxWidth: screenWidth < 800 ? 110 : 160,
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                user?.name ?? 'Administrator',
                                                overflow: TextOverflow.ellipsis,
                                                style: tt.labelLarge?.copyWith(fontSize: 12.5),
                                              ),
                                              Text(
                                                user?.role?.displayName ?? user?.email ?? 'User',
                                                overflow: TextOverflow.ellipsis,
                                                style: tt.bodySmall?.copyWith(fontSize: 10.5),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Main Content Canvas
                      Expanded(
                        child: Container(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          child: widget.child,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopActionButton({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final cs = Theme.of(context).colorScheme;
    final sem = context.semantic;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.control),
        hoverColor: sem.hoverBg,
        child: Container(
          width: 44,
          height: 40,
          decoration: BoxDecoration(
            color: sem.subtleBg,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(color: cs.outlineVariant),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 16,
            color: iconColor ?? cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGroupedSidebarItems(
    BuildContext context,
    List<NavItemData> items,
    String currentRoute,
    bool showExpanded,
  ) {
    final sem = context.semantic;
    final List<Widget> widgets = [];
    String? lastGroup;

    for (final item in items) {
      if (item.group != lastGroup) {
        if (lastGroup != null) {
          widgets.add(const SizedBox(height: AppSpacing.lg));
        }
        if (showExpanded) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 2, 10, 6),
              child: Text(
                item.group,
                style: context.monoStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.7,
                  color: sem.textFaint,
                ),
              ),
            ),
          );
        }
        lastGroup = item.group;
      }

      final isSelected = currentRoute == item.route ||
          (item.route != '/dashboard' && currentRoute.startsWith(item.route));

      widgets.add(
        _buildSidebarTile(
          context: context,
          title: item.title,
          icon: item.icon,
          isSelected: isSelected,
          showExpanded: showExpanded,
          onTap: isSelected ? () {} : () => context.go(item.route),
        ),
      );
    }

    return widgets;
  }

  Widget _buildSidebarTile({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool isSelected,
    required bool showExpanded,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sem = context.semantic;

    final Color activeBg = isSelected ? cs.primaryContainer : Colors.transparent;
    final Color iconColor = isDanger
        ? sem.danger
        : (isSelected ? cs.onPrimaryContainer : cs.onSurfaceVariant);
    final Color textColor = isDanger
        ? sem.danger
        : (isSelected ? cs.onPrimaryContainer : sem.textSecondary);

    final tile = Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.control),
          hoverColor: isSelected ? activeBg : sem.hoverBg,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            height: 44,
            decoration: BoxDecoration(
              color: activeBg,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: Row(
              mainAxisAlignment:
                  showExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                if (showExpanded)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutCubic,
                    width: 3,
                    height: isSelected ? 20 : 0,
                    margin: const EdgeInsets.only(left: 2, right: 9),
                    decoration: BoxDecoration(
                      color: isSelected ? cs.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.tag),
                    ),
                  ),
                Icon(icon, size: 17, color: iconColor),
                if (showExpanded) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: tt.bodyMedium?.copyWith(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: textColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (!showExpanded) {
      return Tooltip(message: title, child: tile);
    }
    return tile;
  }

  Widget _buildMobileDrawer(
    BuildContext context,
    List<NavItemData> visibleNavItems,
    String currentRoute,
  ) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Drawer(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: cs.outlineVariant)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                    alignment: Alignment.center,
                    child: Icon(LucideIcons.barChart2, color: cs.onPrimary, size: 15),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sales Insentif',
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.x, size: 17, color: cs.onSurfaceVariant),
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + 2,
                  vertical: AppSpacing.md,
                ),
                children: _buildGroupedSidebarItems(
                  context,
                  visibleNavItems,
                  currentRoute,
                  true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
