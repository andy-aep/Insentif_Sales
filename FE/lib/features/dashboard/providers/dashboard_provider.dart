import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';

class DashboardState {
  final bool isLoading;
  final String? errorMessage;
  final String mode; // 'ADMIN' or 'SALES'
  final String selectedPeriod;
  final List<String> availablePeriods;
  final Map<String, dynamic> kpi;
  final List<dynamic> leaderboard;
  final List<dynamic> distributors;
  final List<dynamic> monthlyTrend;
  final List<dynamic> breakdown;
  final List<dynamic> incentiveDetails;
  final Map<String, dynamic>? user;

  DashboardState({
    this.isLoading = false,
    this.errorMessage,
    this.mode = 'ADMIN',
    this.selectedPeriod = '',
    this.availablePeriods = const [],
    this.kpi = const {},
    this.leaderboard = const [],
    this.distributors = const [],
    this.monthlyTrend = const [],
    this.breakdown = const [],
    this.incentiveDetails = const [],
    this.user,
  });

  DashboardState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? mode,
    String? selectedPeriod,
    List<String>? availablePeriods,
    Map<String, dynamic>? kpi,
    List<dynamic>? leaderboard,
    List<dynamic>? distributors,
    List<dynamic>? monthlyTrend,
    List<dynamic>? breakdown,
    List<dynamic>? incentiveDetails,
    Map<String, dynamic>? user,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      mode: mode ?? this.mode,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      availablePeriods: availablePeriods ?? this.availablePeriods,
      kpi: kpi ?? this.kpi,
      leaderboard: leaderboard ?? this.leaderboard,
      distributors: distributors ?? this.distributors,
      monthlyTrend: monthlyTrend ?? this.monthlyTrend,
      breakdown: breakdown ?? this.breakdown,
      incentiveDetails: incentiveDetails ?? this.incentiveDetails,
      user: user ?? this.user,
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier() : super(DashboardState()) {
    fetchSummary();
  }

  Future<void> fetchSummary({String? period}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final query = <String, dynamic>{};
      if (period != null && period.isNotEmpty) {
        query['period'] = period;
      } else if (state.selectedPeriod.isNotEmpty) {
        query['period'] = state.selectedPeriod;
      }

      final response = await DioClient.instance.get(
        ApiEndpoints.dashboardSummary,
        queryParameters: query,
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final mode = (data['mode'] ?? 'ADMIN').toString().toUpperCase();
        final currentPeriod = (data['period'] ?? '').toString();
        final rawPeriods = data['available_periods'] as List? ?? [];
        final periods = rawPeriods.map((e) => e.toString()).toList();
        final kpi = (data['kpi'] as Map<String, dynamic>?) ?? {};
        final leaderboard = (data['leaderboard'] as List?) ?? [];
        final distributors = (data['distributors'] as List?) ?? [];
        final monthlyTrend = (data['monthly_trend'] as List?) ?? [];
        final breakdown = (data['breakdown'] as List?) ?? [];
        final incentiveDetails = (data['incentive_details'] as List?) ?? [];
        final user = (data['user'] as Map<String, dynamic>?);

        state = state.copyWith(
          isLoading: false,
          mode: mode,
          selectedPeriod: currentPeriod,
          availablePeriods: periods,
          kpi: kpi,
          leaderboard: leaderboard,
          distributors: distributors,
          monthlyTrend: monthlyTrend,
          breakdown: breakdown,
          incentiveDetails: incentiveDetails,
          user: user,
        );
      } else {
        state = state.copyWith(isLoading: false, errorMessage: 'Format data tidak sesuai');
      }
    } on DioException catch (dioErr) {
      final statusCode = dioErr.response?.statusCode;
      final msg = statusCode == 401
          ? 'Sesi login telah berakhir (401). Silakan login kembali.'
          : 'Gagal memuat dashboard: ${dioErr.message}';
      state = state.copyWith(
        isLoading: false,
        errorMessage: msg,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Terjadi kesalahan: $e',
      );
    }
  }

  void changePeriod(String newPeriod) {
    if (newPeriod != state.selectedPeriod) {
      fetchSummary(period: newPeriod);
    }
  }
}

final dashboardProvider = StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier();
});

