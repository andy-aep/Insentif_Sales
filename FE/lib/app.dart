import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return DashboardLayout(child: child);
        },
        routes: [
          // 1. Dashboard
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardHomeScreen(),
          ),
          // 2. Setting Insentif 3-Level
          GoRoute(
            path: '/settings/incentives',
            builder: (context, state) => const IncentiveSchemeScreen(),
          ),
          // 3. Master Distributor (Hierarki Distributor -> Depo -> Area & Brand)
          GoRoute(
            path: '/master/distributor',
            builder: (context, state) => const MasterDistributorScreen(),
          ),
          // 4. Master Realisasi (Sell-In / Sell-Out SAP & Upload)
          GoRoute(
            path: '/master/realisasi',
            builder: (context, state) => const MasterRealisasiScreen(),
          ),
          // 5. Master Sales (Assign Distributor & Surabaya)
          GoRoute(
            path: '/master/surabaya',
            builder: (context, state) => const MasterSurabayaScreen(),
          ),
          // 6. Master Target Kuota (Distributor, Industri, Surabaya)
          GoRoute(
            path: '/master/target',
            builder: (context, state) => const MasterTargetScreen(),
          ),
          // 7. Insentif Distributor (Konsumsi)
          GoRoute(
            path: '/incentives/distributor',
            builder: (context, state) => const IncentiveCalculationScreen(initialKategori: 'KONSUMSI'),
          ),
          // 8. Insentif Industri
          GoRoute(
            path: '/incentives/industri',
            builder: (context, state) => const IncentiveCalculationScreen(initialKategori: 'INDUSTRI'),
          ),
          // 9. Insentif Surabaya
          GoRoute(
            path: '/incentives/surabaya',
            builder: (context, state) => const IncentiveCalculationScreen(initialKategori: 'SURABAYA'),
          ),
          // 10. Bulk Upload & Rollback Center
          GoRoute(
            path: '/bulk-upload',
            builder: (context, state) => const BulkUploadScreen(),
          ),
          // 11. Users & Hak Akses (User CRUD, Role, Posisi & Menu)
          GoRoute(
            path: '/users',
            builder: (context, state) => const UserManagementScreen(),
          ),
          // Backwards compatibility alias
          GoRoute(
            path: '/incentives/calculate',
            builder: (context, state) => const IncentiveCalculationScreen(),
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
    final router = ref.watch(routerProvider);

    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'Sistem Insentif Sales',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
