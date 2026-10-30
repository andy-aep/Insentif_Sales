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
  final String? group;

  const NavItemData({
    required this.title,
    required this.route,
    required this.icon,
    this.permissionKey,
    this.group,
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
      title: 'Dashboard & KPI',
      route: '/dashboard',
      icon: LucideIcons.layoutDashboard,
      group: 'Utama',
    ),
    NavItemData(
      title: 'Setting Insentif',
      route: '/settings/incentives',
      icon: LucideIcons.sliders,
      group: 'Konfigurasi',
    ),
    NavItemData(
      title: 'Master Distributor',
      route: '/master/distributor',
      icon: LucideIcons.building2,
      group: 'Master Data',
    ),
    NavItemData(
      title: 'Master Realisasi (Sell-In/Out)',
      route: '/master/realisasi',
      icon: LucideIcons.shoppingBag,
      group: 'Master Data',
    ),
    NavItemData(
      title: 'Master Sales',
      route: '/master/surabaya',
      icon: LucideIcons.users,
      group: 'Master Data',
    ),
    NavItemData(
      title: 'Master Target Kuota',
      route: '/master/target',
      icon: LucideIcons.target,
      group: 'Master Data',
    ),
    NavItemData(
      title: 'Insentif Distributor',
      route: '/incentives/distributor',
      icon: LucideIcons.coins,
      group: 'Kalkulasi Skema',
    ),
    NavItemData(
      title: 'Insentif Industri',
      route: '/incentives/industri',
      icon: LucideIcons.factory,
      group: 'Kalkulasi Skema',
    ),
    NavItemData(
      title: 'Insentif Surabaya',
      route: '/incentives/surabaya',
      icon: LucideIcons.landmark,
      group: 'Kalkulasi Skema',
    ),
    NavItemData(
      title: 'Bulk Upload & Rollback',
      route: '/bulk-upload',
      icon: LucideIcons.uploadCloud,
      group: 'Operasional',
    ),
    NavItemData(
      title: 'Users & Hak Akses',
      route: '/users',
      icon: LucideIcons.users,
      group: 'Keamanan',
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

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.bgDialog,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: context.colors.border),
        ),
        title: Row(
          children: [
            const Icon(LucideIcons.logOut, color: AppColors.danger, size: 20),
            const SizedBox(width: 10),
            Text(
              'Konfirmasi Keluar',
              style: GoogleFonts.outfit(color: context.colors.textPrimary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin keluar dari sesi aplikasi?',
          style: GoogleFonts.inter(color: context.colors.textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: GoogleFonts.inter(color: context.colors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
            child: Text('Keluar', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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
      body: Row(
        children: [
          // Dynamic Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: showExpandedSidebar ? 275 : (isDesktop ? 76 : 0),
            curve: Curves.easeInOut,
            child: showExpandedSidebar || isDesktop
                ? Container(
                    decoration: BoxDecoration(
                      color: context.colors.bgCard,
                      border: Border(
                        right: BorderSide(color: context.colors.border, width: 1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Brand Logo
                        Container(
                          height: 70,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: context.colors.border, width: 1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  LucideIcons.trendingUp,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              if (showExpandedSidebar) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Sales Incentive',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          color: context.colors.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'Enterprise System',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
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

                        // Navigation Items
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                            children: visibleNavItems.map((item) {
                              final isSelected = currentRoute == item.route ||
                                  (item.route != '/dashboard' && currentRoute.startsWith(item.route));

                              return Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                child: InkWell(
                                  onTap: () => context.go(item.route),
                                  borderRadius: BorderRadius.circular(10),
                                  hoverColor: context.colors.bgHover,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: showExpandedSidebar ? 12 : 0,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.primary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: showExpandedSidebar
                                          ? MainAxisAlignment.start
                                          : MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          item.icon,
                                          size: 19,
                                          color: isSelected ? Colors.white : context.colors.textMuted,
                                        ),
                                        if (showExpandedSidebar) ...[
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                color: isSelected ? Colors.white : context.colors.textSecondary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        // Sidebar Bottom Toggle
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: context.colors.border, width: 1)),
                          ),
                          child: InkWell(
                            onTap: () => setState(() => _sidebarExpanded = !_sidebarExpanded),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                              child: Row(
                                mainAxisAlignment: showExpandedSidebar
                                    ? MainAxisAlignment.start
                                    : MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    showExpandedSidebar ? LucideIcons.chevronLeft : LucideIcons.chevronRight,
                                    color: context.colors.textMuted,
                                    size: 18,
                                  ),
                                  if (showExpandedSidebar) ...[
                                    const SizedBox(width: 10),
                                    Text(
                                      'Sembunyikan Sidebar',
                                      style: GoogleFonts.inter(fontSize: 12, color: context.colors.textMuted),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Main Screen Content + Topbar
          Expanded(
            child: Column(
              children: [
                // Topbar Header
                Container(
                  height: 70,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: context.colors.bgCard,
                    border: Border(bottom: BorderSide(color: context.colors.border, width: 1)),
                  ),
                  child: Row(
                    children: [
                      if (!isDesktop) ...[
                        IconButton(
                          icon: Icon(LucideIcons.menu, color: context.colors.textPrimary),
                          tooltip: 'Buka Menu',
                          onPressed: () {
                            _scaffoldKey.currentState?.openDrawer();
                          },
                        ),
                        const SizedBox(width: 8),
                      ],

                      if (screenWidth >= 640)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: context.isDarkMode ? 0.15 : 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Text('Laravel 13 API (Online)', style: GoogleFonts.inter(fontSize: 12, color: context.isDarkMode ? AppColors.primaryLight : AppColors.primary, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),

                      const Spacer(),

                      if (screenWidth >= 900) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: context.colors.bgElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: context.colors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.calendar, size: 14, color: AppColors.warning),
                              const SizedBox(width: 8),
                              Text('Periode Aktif: 202610', style: GoogleFonts.inter(fontSize: 12.5, color: context.colors.textPrimary, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],

                      // Theme Toggle (Light / Dark)
                      Container(
                        margin: const EdgeInsets.only(right: 14),
                        decoration: BoxDecoration(
                          color: context.colors.bgElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: context.colors.border),
                        ),
                        child: IconButton(
                          icon: Icon(
                            context.isDarkMode ? LucideIcons.sun : LucideIcons.moon,
                            size: 17,
                            color: context.isDarkMode ? AppColors.warning : AppColors.primary,
                          ),
                          tooltip: context.isDarkMode ? 'Beralih ke Mode Terang' : 'Beralih ke Mode Gelap',
                          onPressed: () {
                            ref.read(themeProvider.notifier).toggleTheme();
                          },
                        ),
                      ),

                      // User Profile Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: context.colors.bgElevated,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: context.colors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.primary,
                              child: Text((user?.name.isNotEmpty == true ? user!.name[0] : 'A').toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            if (screenWidth >= 520) ...[
                              const SizedBox(width: 8),
                              ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: screenWidth < 800 ? 110 : 160),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      user?.name ?? 'Administrator',
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.colors.textPrimary),
                                    ),
                                    Text(
                                      user?.role?.displayName ?? 'Super Admin',
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(fontSize: 10, color: context.colors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(width: 4),
                            IconButton(
                              icon: Icon(LucideIcons.logOut, size: 16, color: context.colors.textMuted),
                              tooltip: 'Keluar',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _showLogoutDialog,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Page Body
                Expanded(
                  child: Container(
                    color: context.colors.bgScaffold,
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

  Widget _buildMobileDrawer(BuildContext context, List<NavItemData> visibleNavItems, String currentRoute) {
    return Drawer(
      backgroundColor: context.colors.bgCard,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drawer Header with Logo & Close button
            Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: context.colors.border, width: 1)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.trendingUp, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Sales Incentive',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16, color: context.colors.textPrimary),
                        ),
                        Text('Enterprise System', style: GoogleFonts.inter(fontSize: 11, color: context.colors.textMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.x, size: 18, color: context.colors.textMuted),
                    tooltip: 'Tutup Menu',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                children: visibleNavItems.map((item) {
                  final isSelected = currentRoute == item.route ||
                      (item.route != '/dashboard' && currentRoute.startsWith(item.route));

                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        context.go(item.route);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.icon,
                              size: 19,
                              color: isSelected ? Colors.white : context.colors.textMuted,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.title,
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  color: isSelected ? Colors.white : context.colors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
