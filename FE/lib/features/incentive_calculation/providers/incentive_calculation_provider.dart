import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/web_downloader.dart';
import '../../../data/models/calculation_model.dart';

class IncentiveCalculationState {
  final bool isLoading;
  final bool isCalculating;
  final bool isExporting;
  final List<IncentiveCalculationModel> results;
  final List<DistributorBreakdownCardModel> breakdownCards;
  final bool isBreakdownView;
  final IncentiveSummaryMeta summary;
  final String selectedKategori;
  final String selectedPeriod;
  final int? selectedPositionId;
  final int? selectedUserId;
  final String searchQuery;
  final String? errorMessage;
  final String? successMessage;

  IncentiveCalculationState({
    this.isLoading = false,
    this.isCalculating = false,
    this.isExporting = false,
    this.results = const [],
    this.breakdownCards = const [],
    this.isBreakdownView = true,
    required this.summary,
    this.selectedKategori = 'KONSUMSI',
    this.selectedPeriod = '202610',
    this.selectedPositionId,
    this.selectedUserId,
    this.searchQuery = '',
    this.errorMessage,
    this.successMessage,
  });

  IncentiveCalculationState copyWith({
    bool? isLoading,
    bool? isCalculating,
    bool? isExporting,
    List<IncentiveCalculationModel>? results,
    List<DistributorBreakdownCardModel>? breakdownCards,
    bool? isBreakdownView,
    IncentiveSummaryMeta? summary,
    String? selectedKategori,
    String? selectedPeriod,
    int? selectedPositionId,
    int? selectedUserId,
    String? searchQuery,
    String? errorMessage,
    String? successMessage,
    bool clearPosition = false,
    bool clearUser = false,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return IncentiveCalculationState(
      isLoading: isLoading ?? this.isLoading,
      isCalculating: isCalculating ?? this.isCalculating,
      isExporting: isExporting ?? this.isExporting,
      results: results ?? this.results,
      breakdownCards: breakdownCards ?? this.breakdownCards,
      isBreakdownView: isBreakdownView ?? this.isBreakdownView,
      summary: summary ?? this.summary,
      selectedKategori: selectedKategori ?? this.selectedKategori,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      selectedPositionId: clearPosition ? null : (selectedPositionId ?? this.selectedPositionId),
      selectedUserId: clearUser ? null : (selectedUserId ?? this.selectedUserId),
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class IncentiveCalculationNotifier extends StateNotifier<IncentiveCalculationState> {
  IncentiveCalculationNotifier()
      : super(IncentiveCalculationState(
          summary: IncentiveSummaryMeta(
            totalPersonil: 0,
            totalQuota: 0,
            totalRealization: 0,
            totalReward: 0,
            avgAchievement: 0,
          ),
        )) {
    fetchResults();
  }

  void setKategori(String kategori) {
    final normalized = kategori.toUpperCase() == 'DISTRIBUTOR' ? 'KONSUMSI' : kategori.toUpperCase();
    if (state.selectedKategori == normalized && (state.results.isNotEmpty || state.breakdownCards.isNotEmpty || state.isLoading)) {
      return;
    }
    state = state.copyWith(
      selectedKategori: normalized,
      clearPosition: true,
      clearUser: true,
    );
    fetchResults();
  }

  void setPosition(int? positionId) {
    state = state.copyWith(
      selectedPositionId: positionId,
      clearPosition: positionId == null,
      clearUser: true,
    );
    fetchResults();
  }

  void setUser(int? userId) {
    state = state.copyWith(
      selectedUserId: userId,
      clearUser: userId == null,
    );
    fetchResults();
  }

  void setPeriod(String period) {
    state = state.copyWith(selectedPeriod: period);
    fetchResults();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void toggleViewMode() {
    state = state.copyWith(isBreakdownView: !state.isBreakdownView);
  }

  void setBreakdownView(bool val) {
    state = state.copyWith(isBreakdownView: val);
  }

  Future<void> fetchResults() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final queryParams = <String, dynamic>{
        'kategori_skema': state.selectedKategori,
        'period': state.selectedPeriod,
        if (state.selectedPositionId != null) 'position_id': state.selectedPositionId,
        if (state.selectedUserId != null) 'user_id': state.selectedUserId,
        'per_page': 200,
      };

      // 1. Fetch Summary rows
      final response = await DioClient.instance.get(
        ApiEndpoints.incentiveResults,
        queryParameters: queryParams,
      );

      final data = response.data;
      List<IncentiveCalculationModel> items = [];
      if (data is List) {
        items = data.map((json) => IncentiveCalculationModel.fromJson(json)).toList();
      } else if (data is Map && data['data'] is List) {
        items = (data['data'] as List).map((json) => IncentiveCalculationModel.fromJson(json)).toList();
      }

      final summary = IncentiveSummaryMeta.fromCalculations(items);

      // 2. Fetch Hierarchical Distributor Breakdown Cards if KONSUMSI
      List<DistributorBreakdownCardModel> breakdownCards = [];
      if (state.selectedKategori == 'KONSUMSI') {
        try {
          final breakdownRes = await DioClient.instance.get(
            ApiEndpoints.incentiveDistributorBreakdown,
            queryParameters: {
              'period': state.selectedPeriod,
              if (state.selectedPositionId != null) 'position_id': state.selectedPositionId,
              if (state.selectedUserId != null) 'user_id': state.selectedUserId,
            },
          );
          final rawCards = breakdownRes.data?['data'] as List? ?? [];
          breakdownCards = rawCards
              .map((c) => DistributorBreakdownCardModel.fromJson(c as Map<String, dynamic>))
              .toList();
        } catch (_) {}
      }

      state = state.copyWith(
        isLoading: false,
        results: items,
        breakdownCards: breakdownCards,
        summary: summary,
      );
    } on DioException catch (dioErr) {
      final err = ApiException.fromDioException(dioErr);
      state = state.copyWith(isLoading: false, errorMessage: err.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> calculate() async {
    state = state.copyWith(isCalculating: true, clearError: true, clearSuccess: true);
    try {
      final response = await DioClient.instance.post(
        ApiEndpoints.calculateIncentive,
        data: {
          'kategori_skema': state.selectedKategori,
          'period': state.selectedPeriod,
          if (state.selectedPositionId != null) 'position_id': state.selectedPositionId,
          if (state.selectedUserId != null) 'user_id': state.selectedUserId,
        },
      );

      final msg = response.data?['message'] ?? 'Kalkulasi insentif berhasil diproses.';
      state = state.copyWith(
        isCalculating: false,
        successMessage: msg.toString(),
      );
      await fetchResults();
    } on DioException catch (dioErr) {
      final err = ApiException.fromDioException(dioErr);
      state = state.copyWith(isCalculating: false, errorMessage: err.message);
    } catch (e) {
      state = state.copyWith(isCalculating: false, errorMessage: e.toString());
    }
  }

  Future<void> exportExcel() async {
    state = state.copyWith(isExporting: true, clearError: true, clearSuccess: true);
    try {
      final filename = 'Insentif_${state.selectedKategori}_${state.selectedPeriod}.xlsx';
      await WebDownloader.downloadExcel(
        ApiEndpoints.exportExcel,
        filename,
        queryParameters: {
          'kategori_skema': state.selectedKategori,
          'period': state.selectedPeriod,
          if (state.selectedPositionId != null) 'position_id': state.selectedPositionId.toString(),
          if (state.selectedUserId != null) 'user_id': state.selectedUserId.toString(),
        },
      );
      state = state.copyWith(
        isExporting: false,
        successMessage: 'Laporan Excel berhasil diunduh ($filename)',
      );
    } on DioException catch (dioErr) {
      final err = ApiException.fromDioException(dioErr);
      state = state.copyWith(isExporting: false, errorMessage: err.message);
    } catch (e) {
      state = state.copyWith(isExporting: false, errorMessage: e.toString());
    }
  }
}

final incentiveCalculationProvider =
    StateNotifierProvider<IncentiveCalculationNotifier, IncentiveCalculationState>((ref) {
  return IncentiveCalculationNotifier();
});
