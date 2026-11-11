import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/network/dio_client.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/dashboard/presentation/dashboard_home_screen.dart';
import 'features/dashboard/presentation/dashboard_layout.dart';
import 'features/incentive_calculation/presentation/incentive_calculation_screen.dart';
import 'features/bulk_upload/presentation/bulk_upload_screen.dart';
import 'features/incentive_settings/presentation/incentive_scheme_screen.dart';
import 'features/master_data/presentation/master_distributor_screen.dart';
import 'features/master_data/presentation/master_realisasi_screen.dart';
import 'features/master_data/presentation/master_surabaya_screen.dart';
import 'features/master_data/presentation/master_target_screen.dart';
import 'features/users_management/presentation/user_management_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      if (authState.isLoading) return null;

      final isLoggingIn = state.matchedLocation == '/login';
      final isLoggedIn = authState.isAuthenticated;

      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }

      if (isLoggedIn && isLoggingIn) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => const NoTransitionPage(child: LoginScreen()),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return DashboardLayout(child: child);
        },
        routes: [
          // 1. Dashboard
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) => const NoTransitionPage(child: DashboardHomeScreen()),
          ),
          // 2. Setting Insentif 3-Level
          GoRoute(
            path: '/settings/incentives',
            pageBuilder: (context, state) => const NoTransitionPage(child: IncentiveSchemeScreen()),
          ),
          // 3. Master Distributor (Hierarki Distributor -> Depo -> Area & Brand)
          GoRoute(
            path: '/master/distributor',
            pageBuilder: (context, state) => const NoTransitionPage(child: MasterDistributorScreen()),
          ),
          // 4. Master Realisasi (Sell-In / Sell-Out SAP & Upload)
          GoRoute(
            path: '/master/realisasi',
            pageBuilder: (context, state) => const NoTransitionPage(child: MasterRealisasiScreen()),
          ),
          // 5. Master Sales (Assign Distributor & Surabaya)
          GoRoute(
            path: '/master/surabaya',
            pageBuilder: (context, state) => const NoTransitionPage(child: MasterSurabayaScreen()),
          ),
          // 6. Master Target Kuota (Distributor, Industri, Surabaya)
          GoRoute(
            path: '/master/target',
            pageBuilder: (context, state) => const NoTransitionPage(child: MasterTargetScreen()),
          ),
          // 7. Insentif Distributor (Konsumsi)
          GoRoute(
            path: '/incentives/distributor',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: IncentiveCalculationScreen(
                key: ValueKey('KONSUMSI'),
                initialKategori: 'KONSUMSI',
              ),
            ),
          ),
          // 8. Insentif Industri
          GoRoute(
            path: '/incentives/industri',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: IncentiveCalculationScreen(
                key: ValueKey('INDUSTRI'),
                initialKategori: 'INDUSTRI',
              ),
            ),
          ),
          // 9. Insentif Surabaya
          GoRoute(
            path: '/incentives/surabaya',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: IncentiveCalculationScreen(
                key: ValueKey('SURABAYA'),
                initialKategori: 'SURABAYA',
              ),
            ),
          ),
          // 10. Bulk Upload & Rollback Center
          GoRoute(
            path: '/bulk-upload',
            pageBuilder: (context, state) => const NoTransitionPage(child: BulkUploadScreen()),
          ),
          // 11. Users & Hak Akses (User CRUD, Role, Posisi & Menu)
          GoRoute(
            path: '/users',
            pageBuilder: (context, state) => const NoTransitionPage(child: UserManagementScreen()),
          ),
          // Backwards compatibility alias
          GoRoute(
            path: '/incentives/calculate',
            pageBuilder: (context, state) => const NoTransitionPage(child: IncentiveCalculationScreen()),
          ),
        ],
      ),
    ],
  );
});

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class SalesIncentiveApp extends ConsumerWidget {
  const SalesIncentiveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    DioClient.onUnauthorized = () {
      ref.read(authProvider.notifier).logout(remote: false);
    };

    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'Sales Insentif',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
