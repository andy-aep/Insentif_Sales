import 'package:flutter/material.dart';
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
      group: 'MENU',
    ),
    NavItemData(
      title: 'Master Distributor',
      route: '/master/distributor',
      icon: LucideIcons.building2,
      group: 'MENU',
    ),
    NavItemData(
      title: 'Master Target Kuota',
      route: '/master/target',
      icon: LucideIcons.target,
      group: 'MENU',
    ),
    NavItemData(
      title: 'Realisasi Penjualan',
      route: '/master/realisasi',
      icon: LucideIcons.shoppingBag,
      group: 'MENU',
    ),
    NavItemData(
      title: 'Tim & Area Sales',
      route: '/master/surabaya',
      icon: LucideIcons.users,
      group: 'MENU',
    ),
    NavItemData(
      title: 'Insentif Distributor',
      route: '/incentives/distributor',
      icon: LucideIcons.coins,
      group: 'KALKULASI',
    ),
    NavItemData(
      title: 'Insentif Industri',
      route: '/incentives/industri',
      icon: LucideIcons.factory,
      group: 'KALKULASI',
    ),
    NavItemData(
      title: 'Insentif Surabaya',
      route: '/incentives/surabaya',
      icon: LucideIcons.landmark,
      group: 'KALKULASI',
    ),
    NavItemData(
      title: 'Skema & Bobot',
      route: '/settings/incentives',
      icon: LucideIcons.sliders,
      group: 'UMUM',
    ),
    NavItemData(
      title: 'Bulk Upload Data',
      route: '/bulk-upload',
      icon: LucideIcons.uploadCloud,
      group: 'UMUM',
    ),
    NavItemData(
      title: 'Pengguna & Akses',
      route: '/users',
      icon: LucideIcons.shield,
      group: 'UMUM',
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

  void _showQuickJumpDialog(List<NavItemData> items) {
    showDialog(
      context: context,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final cs = Theme.of(ctx).colorScheme;
            final tt = Theme.of(ctx).textTheme;
            final filtered = items
                .where((i) =>
                    i.title.toLowerCase().contains(query.toLowerCase()) ||
                    i.group.toLowerCase().contains(query.toLowerCase()))
                .toList();
            return Dialog(
              backgroundColor: cs.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: cs.outlineVariant),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460, maxHeight: 420),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        autofocus: true,
                        onChanged: (v) => setDialogState(() => query = v),
                        style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Ketik nama menu untuk berpindah halaman...',
                          prefixIcon: const Icon(LucideIcons.search, size: 17),
                          filled: true,
                          fillColor: cs.surfaceContainerLow,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (_, idx) {
                            final item = filtered[idx];
                            return ListTile(
                              dense: true,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              leading: Icon(item.icon, size: 18, color: cs.primary),
                              title: Text(
                                item.title,
                                style: tt.titleSmall,
                              ),
                              trailing: Text(
                                item.group,
                                style: tt.labelSmall,
                              ),
                              onTap: () {
                                Navigator.pop(ctx);
                                context.go(item.route);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
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
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: cs.outlineVariant),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(LucideIcons.key, color: cs.primary, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  'Ganti Kata Sandi Saya',
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
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: sem.danger.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.alertCircle, color: sem.danger, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorText!,
                              style: tt.bodySmall?.copyWith(color: sem.danger, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextField(
                    controller: currentPassCtrl,
                    obscureText: obscureCurrent,
                    style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Kata Sandi Saat Ini',
                      suffixIcon: IconButton(
                        icon: Icon(obscureCurrent ? LucideIcons.eyeOff : LucideIcons.eye, size: 18),
                        onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPassCtrl,
                    obscureText: obscureNew,
                    style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Kata Sandi Baru',
                      hintText: 'Minimal 6 karakter',
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? LucideIcons.eyeOff : LucideIcons.eye, size: 18),
                        onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPassCtrl,
                    obscureText: obscureConfirm,
                    style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Konfirmasi Kata Sandi Baru',
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? LucideIcons.eyeOff : LucideIcons.eye, size: 18),
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
                    setDialogState(() => errorText = 'Masukkan kata sandi saat ini');
                    return;
                  }
                  if (nw.length < 6) {
                    setDialogState(() => errorText = 'Kata sandi baru minimal 6 karakter');
                    return;
                  }
                  if (nw != conf) {
                    setDialogState(() => errorText = 'Konfirmasi kata sandi tidak cocok');
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
                        content: Text(msg ?? 'Kata sandi berhasil diubah'),
                        backgroundColor: sem.successSolid,
                      ),
                    );
                  } else {
                    setDialogState(() => errorText = msg ?? 'Gagal memperbarui kata sandi');
                  }
                },
                child: const Text('Simpan Sandi'),
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
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: cs.outlineVariant),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          title: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
                ),
                alignment: Alignment.center,
                child: Text(
                  (user?.name.isNotEmpty == true ? user!.name[0] : 'U').toUpperCase(),
                  style: tt.titleLarge?.copyWith(color: cs.primary),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? 'Pengguna',
                      style: tt.titleMedium,
                    ),
                    Text(
                      '@${user?.username ?? '-'} • ${user?.role?.displayName ?? 'User'}',
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
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: sem.subtleBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      _buildProfileRow(ctx, 'Posisi', user?.position?.name ?? 'Tanpa Posisi'),
                      const SizedBox(height: 8),
                      _buildProfileRow(ctx, 'Email', user?.email ?? '-'),
                      const SizedBox(height: 8),
                      _buildProfileRow(ctx, 'Role Akses', user?.role?.displayName ?? '-'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.primary,
                    side: BorderSide(color: cs.primary.withValues(alpha: 0.45)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(LucideIcons.key, size: 16),
                  label: const Text('Ganti Kata Sandi Saya'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showChangeOwnPasswordDialog();
                  },
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sem.dangerBg,
                    foregroundColor: sem.danger,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(LucideIcons.logOut, size: 16),
                  label: const Text('Keluar dari Akun (Logout)'),
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
        const SizedBox(width: 12),
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
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: cs.outlineVariant),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: sem.dangerBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(LucideIcons.logOut, color: sem.danger, size: 18),
              ),
              const SizedBox(width: 12),
              Text('Keluar dari Sesi', style: tt.titleLarge),
            ],
          ),
          content: Text(
            'Apakah Anda yakin ingin keluar dari aplikasi?',
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

    return Scaffold(
      key: _scaffoldKey,
      drawer: !isDesktop ? _buildMobileDrawer(context, visibleNavItems, currentRoute) : null,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(
        children: [
          // Clean SaaS Left Sidebar
          if (isDesktop)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: showExpandedSidebar ? 248 : 72,
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
                    height: 64,
                    padding: EdgeInsets.symmetric(horizontal: showExpandedSidebar ? 18 : 14),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: cs.outlineVariant)),
                    ),
                    child: Row(
                      mainAxisAlignment: showExpandedSidebar
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            LucideIcons.layoutGrid,
                            color: cs.onPrimary,
                            size: 18,
                          ),
                        ),
                        if (showExpandedSidebar) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Sales Insentif',
                              style: tt.titleLarge?.copyWith(fontSize: 16.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              LucideIcons.panelLeftClose,
                              size: 17,
                              color: cs.onSurfaceVariant,
                            ),
                            tooltip: 'Ringkas Sidebar',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(() => _sidebarExpanded = false),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Grouped Navigation Items
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
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
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: cs.outlineVariant)),
                    ),
                    child: Column(
                      children: [
                        if (!showExpandedSidebar) ...[
                          IconButton(
                            icon: Icon(
                              LucideIcons.panelLeftOpen,
                              size: 18,
                              color: cs.onSurfaceVariant,
                            ),
                            tooltip: 'Perlebar Sidebar',
                            onPressed: () => setState(() => _sidebarExpanded = true),
                          ),
                          const SizedBox(height: 4),
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

          // Right Area: Clean Topbar + Main Canvas
          Expanded(
            child: Column(
              children: [
                // Top AppBar
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    border: Border(bottom: BorderSide(color: cs.outlineVariant)),
                  ),
                  child: Row(
                    children: [
                      if (!isDesktop) ...[
                        IconButton(
                          icon: Icon(LucideIcons.menu, color: cs.onSurface),
                          tooltip: 'Buka Menu',
                          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Quick Search Trigger
                      if (screenWidth >= 560)
                        InkWell(
                          onTap: () => _showQuickJumpDialog(visibleNavItems),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: screenWidth >= 900 ? 300 : 210,
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: sem.subtleBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: cs.outlineVariant),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  LucideIcons.search,
                                  size: 15,
                                  color: cs.onSurfaceVariant,
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    'Cari menu atau fitur...',
                                    style: tt.bodySmall?.copyWith(fontSize: 12.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: cs.surface,
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: cs.outlineVariant),
                                  ),
                                  child: Text(
                                    '⌘F',
                                    style: tt.labelSmall?.copyWith(fontSize: 10.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      const Spacer(),

                      // Quick Upload Button
                      _buildTopActionButton(
                        context: context,
                        icon: LucideIcons.uploadCloud,
                        tooltip: 'Bulk Upload Data',
                        onTap: () => context.go('/bulk-upload'),
                      ),
                      const SizedBox(width: 8),

                      // Light / Dark Mode Toggle
                      _buildTopActionButton(
                        context: context,
                        icon: isDark ? LucideIcons.sun : LucideIcons.moon,
                        tooltip: isDark ? 'Beralih ke Mode Terang' : 'Beralih ke Mode Gelap',
                        iconColor: isDark ? sem.warning : cs.onSurfaceVariant,
                        onTap: () => ref.read(themeProvider.notifier).toggleTheme(),
                      ),
                      const SizedBox(width: 12),

                      Container(
                        width: 1,
                        height: 24,
                        color: cs.outlineVariant,
                      ),
                      const SizedBox(width: 12),

                      // User Profile Button
                      InkWell(
                        onTap: _showProfileDialog,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  (user?.name.isNotEmpty == true ? user!.name[0] : 'A').toUpperCase(),
                                  style: tt.titleSmall?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (screenWidth >= 520) ...[
                                const SizedBox(width: 10),
                                ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: screenWidth < 800 ? 110 : 160),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        user?.name ?? 'Administrator',
                                        overflow: TextOverflow.ellipsis,
                                        style: tt.labelLarge?.copyWith(fontSize: 13),
                                      ),
                                      Text(
                                        user?.email ?? (user?.role?.displayName ?? 'admin@salestify.id'),
                                        overflow: TextOverflow.ellipsis,
                                        style: tt.bodySmall?.copyWith(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
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
        borderRadius: BorderRadius.circular(8),
        hoverColor: sem.hoverBg,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: sem.subtleBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.outlineVariant),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 17,
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
    final tt = Theme.of(context).textTheme;
    final List<Widget> widgets = [];
    String? lastGroup;

    for (final item in items) {
      if (item.group != lastGroup) {
        if (lastGroup != null) {
          widgets.add(const SizedBox(height: 16));
        }
        if (showExpanded) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
              child: Text(
                item.group,
                style: tt.labelSmall?.copyWith(
                  fontSize: 10.5,
                  letterSpacing: 0.8,
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
        : (isSelected ? cs.primary : cs.onSurfaceVariant);
    final Color textColor = isDanger
        ? sem.danger
        : (isSelected ? cs.primary : sem.textSecondary);

    final tile = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: activeBg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: isSelected ? cs.primaryContainer : sem.hoverBg,
          child: Container(
            height: 40,
            padding: EdgeInsets.symmetric(horizontal: showExpanded ? 12 : 0),
            alignment: showExpanded ? Alignment.centerLeft : Alignment.center,
            child: Row(
              mainAxisAlignment: showExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: iconColor),
                if (showExpanded) ...[
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      title,
                      style: tt.bodyMedium?.copyWith(
                        fontSize: 13.5,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: textColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: cs.outlineVariant)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(LucideIcons.layoutGrid, color: cs.onPrimary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sales Insentif',
                      style: tt.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.x, size: 18, color: cs.onSurfaceVariant),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
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
