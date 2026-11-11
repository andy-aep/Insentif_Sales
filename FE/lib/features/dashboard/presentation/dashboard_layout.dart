import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
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
    if (role == null) return true;
    final menuPermissions = role.menuPermissions;
    if (menuPermissions == null || menuPermissions.isEmpty) return true;

    for (final perm in menuPermissions) {
      final menuRoute = perm.menu?.route?.toLowerCase() ?? '';
      final menuName = perm.menu?.name?.toLowerCase() ?? '';
      if (menuRoute.isNotEmpty && item.route.toLowerCase().contains(menuRoute)) {
        return perm.canView;
      }
      if (menuName.isNotEmpty && item.title.toLowerCase().contains(menuName)) {
        return perm.canView;
      }
    }
    return true;
  }

  void _showQuickJumpDialog(List<NavItemData> items) {
    showDialog(
      context: context,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final filtered = items
                .where((i) =>
                    i.title.toLowerCase().contains(query.toLowerCase()) ||
                    i.group.toLowerCase().contains(query.toLowerCase()))
                .toList();
            return Dialog(
              backgroundColor: context.colors.bgCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(color: context.colors.border),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440, maxHeight: 420),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        autofocus: true,
                        onChanged: (v) => setDialogState(() => query = v),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: context.colors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ketik nama menu untuk berpindah halaman...',
                          prefixIcon: const Icon(LucideIcons.search, size: 18),
                          filled: true,
                          fillColor: context.colors.bgElevated,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (_, idx) {
                            final item = filtered[idx];
                            return ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              leading: Icon(item.icon, size: 18, color: AppColors.primary),
                              title: Text(
                                item.title,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: context.colors.textPrimary,
                                ),
                              ),
                              trailing: Text(
                                item.group,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: context.colors.textMuted,
                                ),
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
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: context.colors.bgDialog,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: context.colors.border),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.key, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Ganti Kata Sandi Saya',
                style: GoogleFonts.plusJakartaSans(
                  color: context.colors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.alertCircle, color: AppColors.danger, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorText!,
                            style: GoogleFonts.plusJakartaSans(color: AppColors.danger, fontSize: 12),
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
                  style: TextStyle(color: context.colors.textPrimary),
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
                  style: TextStyle(color: context.colors.textPrimary),
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
                  style: TextStyle(color: context.colors.textPrimary),
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
              child: Text('Batal', style: GoogleFonts.plusJakartaSans(color: context.colors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
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
                      backgroundColor: AppColors.success,
                    ),
                  );
                } else {
                  setDialogState(() => errorText = msg ?? 'Gagal memperbarui kata sandi');
                }
              },
              child: Text('Simpan Sandi', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileDialog() {
    final authState = ref.read(authProvider);
    final user = authState.user;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.bgDialog,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: context.colors.border),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                (user?.name.isNotEmpty == true ? user!.name[0] : 'U').toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.primaryDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.name ?? 'Pengguna',
                    style: GoogleFonts.plusJakartaSans(
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '@${user?.username ?? '-'} • ${user?.role?.displayName ?? 'User'}',
                    style: GoogleFonts.plusJakartaSans(
                      color: context.colors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.bgSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.border),
              ),
              child: Column(
                children: [
                  _buildProfileRow('Posisi', user?.position?.name ?? 'Tanpa Posisi'),
                  const SizedBox(height: 6),
                  _buildProfileRow('Email', user?.email ?? '-'),
                  const SizedBox(height: 6),
                  _buildProfileRow('Role Akses', user?.role?.displayName ?? '-'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                backgroundColor: AppColors.danger.withValues(alpha: 0.12),
                foregroundColor: AppColors.danger,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
  }

  Widget _buildProfileRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(color: context.colors.textMuted, fontSize: 12)),
        Text(value, style: GoogleFonts.plusJakartaSans(color: context.colors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ],
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.bgDialog,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: context.colors.border),
        ),
        title: Row(
          children: [
            const Icon(LucideIcons.logOut, color: AppColors.danger, size: 20),
            const SizedBox(width: 10),
            Text(
              'Keluar dari Sesi',
              style: GoogleFonts.plusJakartaSans(
                color: context.colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin keluar dari aplikasi?',
          style: GoogleFonts.plusJakartaSans(
            color: context.colors.textSecondary,
            fontSize: 13.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: GoogleFonts.plusJakartaSans(color: context.colors.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
            child: Text(
              'Keluar',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
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

    final visibleNavItems = _allNavItems.where((item) {
      return _isItemAllowed(item, user?.role);
    }).toList();

    return Scaffold(
      key: _scaffoldKey,
      drawer: !isDesktop ? _buildMobileDrawer(context, visibleNavItems, currentRoute) : null,
      backgroundColor: context.colors.bgScaffold,
      body: Padding(
        padding: EdgeInsets.all(isDesktop ? 14 : 0),
        child: Row(
          children: [
            // Klaboard Floating Left Sidebar
            if (isDesktop) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: showExpandedSidebar ? 250 : 78,
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: context.colors.bgSubtle,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: context.colors.border.withValues(alpha: 0.7)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Klaboard-style Brand Header
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        showExpandedSidebar ? 24 : 18,
                        24,
                        showExpandedSidebar ? 18 : 18,
                        18,
                      ),
                      child: Row(
                        mainAxisAlignment: showExpandedSidebar
                            ? MainAxisAlignment.start
                            : MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              LucideIcons.layoutGrid,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          if (showExpandedSidebar) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Sales Insentif',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 19,
                                  letterSpacing: -0.4,
                                  color: context.colors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                LucideIcons.panelLeftClose,
                                size: 17,
                                color: context.colors.textMuted,
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
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        children: _buildGroupedSidebarItems(
                          context,
                          visibleNavItems,
                          currentRoute,
                          showExpandedSidebar,
                        ),
                      ),
                    ),

                    // Bottom Logout / Expand Action
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 6, 0, 18),
                      child: Column(
                        children: [
                          if (!showExpandedSidebar)
                            IconButton(
                              icon: Icon(
                                LucideIcons.panelLeftOpen,
                                size: 18,
                                color: context.colors.textMuted,
                              ),
                              tooltip: 'Perlebar Sidebar',
                              onPressed: () => setState(() => _sidebarExpanded = true),
                            ),
                          _buildSidebarTile(
                            context: context,
                            title: 'Keluar',
                            icon: LucideIcons.logOut,
                            isSelected: false,
                            showExpanded: showExpandedSidebar,
                            onTap: _showLogoutDialog,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
            ],

            // Right Area: Floating Topbar + Floating Content Surface
            Expanded(
              child: Column(
                children: [
                  // Klaboard Floating Topbar
                  Container(
                    height: 68,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: context.colors.bgSubtle,
                      borderRadius: BorderRadius.circular(isDesktop ? 22 : 0),
                      border: isDesktop
                          ? Border.all(color: context.colors.border.withValues(alpha: 0.7))
                          : Border(bottom: BorderSide(color: context.colors.border)),
                    ),
                    child: Row(
                      children: [
                        if (!isDesktop) ...[
                          IconButton(
                            icon: Icon(LucideIcons.menu, color: context.colors.textPrimary),
                            tooltip: 'Buka Menu',
                            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                          ),
                          const SizedBox(width: 8),
                        ],

                        // Klaboard Search Pill ("Search task [⌘F]")
                        if (screenWidth >= 560)
                          InkWell(
                            onTap: () => _showQuickJumpDialog(visibleNavItems),
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              width: screenWidth >= 900 ? 310 : 220,
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: context.colors.bgCard,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: context.colors.border.withValues(alpha: 0.8)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    LucideIcons.search,
                                    size: 17,
                                    color: context.colors.textPrimary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Cari menu atau fitur...',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        color: context.colors.textMuted,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: context.colors.bgElevated,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '⌘F',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: context.colors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const Spacer(),

                        // Active Period Soft Pill
                        if (screenWidth >= 860) ...[
                          Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: context.colors.bgCard,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: context.colors.border.withValues(alpha: 0.8)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.calendar, size: 15, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Periode 202610',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    color: context.colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],

                        // Quick Upload Circle Button
                        _buildTopCircleButton(
                          context: context,
                          icon: LucideIcons.uploadCloud,
                          tooltip: 'Bulk Upload Data',
                          onTap: () => context.go('/bulk-upload'),
                        ),
                        const SizedBox(width: 10),

                        // Light / Dark Mode Circle Toggle
                        _buildTopCircleButton(
                          context: context,
                          icon: context.isDarkMode ? LucideIcons.sun : LucideIcons.moon,
                          tooltip: context.isDarkMode ? 'Mode Terang' : 'Mode Gelap',
                          iconColor: context.isDarkMode ? AppColors.primaryLight : context.colors.textPrimary,
                          onTap: () => ref.read(themeProvider.notifier).toggleTheme(),
                        ),
                        const SizedBox(width: 14),

                        // Klaboard Natural User Profile
                        InkWell(
                          onTap: _showProfileDialog,
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.16),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.primary.withValues(alpha: 0.35),
                                      width: 1.5,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    (user?.name.isNotEmpty == true ? user!.name[0] : 'A').toUpperCase(),
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppColors.primaryDark,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (screenWidth >= 520) ...[
                                  const SizedBox(width: 10),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: screenWidth < 800 ? 110 : 150),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          user?.name ?? 'Administrator',
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: context.colors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          user?.email ?? (user?.role?.displayName ?? 'admin@salestify.id'),
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11.5,
                                            color: context.colors.textMuted,
                                          ),
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

                  SizedBox(height: isDesktop ? 14 : 0),

                  // Main Content Rounded Island
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.colors.bgSubtle,
                        borderRadius: BorderRadius.circular(isDesktop ? 24 : 0),
                        border: isDesktop
                            ? Border.all(color: context.colors.border.withValues(alpha: 0.7))
                            : null,
                      ),
                      clipBehavior: isDesktop ? Clip.antiAlias : Clip.none,
                      child: widget.child,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCircleButton({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: context.colors.bgCard,
            shape: BoxShape.circle,
            border: Border.all(color: context.colors.border.withValues(alpha: 0.8)),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color: iconColor ?? context.colors.textPrimary,
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
    final List<Widget> widgets = [];
    String? lastGroup;

    for (final item in items) {
      if (item.group != lastGroup) {
        if (lastGroup != null) {
          widgets.add(const SizedBox(height: 14));
        }
        if (showExpanded) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 6, 16, 8),
              child: Text(
                item.group,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: context.colors.textMuted,
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

  /// Klaboard signature navigation tile:
  /// Vertical terracotta pill indicator on the left edge + warm orange icon + bold charcoal text
  Widget _buildSidebarTile({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool isSelected,
    required bool showExpanded,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: onTap,
        hoverColor: context.colors.bgHover.withValues(alpha: 0.6),
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              // Klaboard Left Orange Indicator Pill
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 6,
                height: isSelected ? 32 : 0,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(6),
                  ),
                ),
              ),
              SizedBox(width: showExpanded ? 18 : 20),
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppColors.primary : context.colors.textMuted,
              ),
              if (showExpanded) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? context.colors.textPrimary
                          : context.colors.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileDrawer(
    BuildContext context,
    List<NavItemData> visibleNavItems,
    String currentRoute,
  ) {
    return Drawer(
      backgroundColor: context.colors.bgSubtle,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 14, 16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(LucideIcons.layoutGrid, color: Colors.white, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Sales Insentif',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.x, size: 18, color: context.colors.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
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
