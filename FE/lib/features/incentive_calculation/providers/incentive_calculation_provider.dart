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
  final IncentiveSummaryMeta summary;
  final String selectedKategori;
  final String selectedPeriod;
  final String searchQuery;
  final String? errorMessage;
  final String? successMessage;

  IncentiveCalculationState({
    this.isLoading = false,
    this.isCalculating = false,
    this.isExporting = false,
    this.results = const [],
    required this.summary,
    this.selectedKategori = 'KONSUMSI',
    this.selectedPeriod = '202610',
    this.searchQuery = '',
    this.errorMessage,
    this.successMessage,
  });

  IncentiveCalculationState copyWith({
    bool? isLoading,
    bool? isCalculating,
    bool? isExporting,
    List<IncentiveCalculationModel>? results,
    IncentiveSummaryMeta? summary,
    String? selectedKategori,
    String? selectedPeriod,
    String? searchQuery,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return IncentiveCalculationState(
      isLoading: isLoading ?? this.isLoading,
      isCalculating: isCalculating ?? this.isCalculating,
      isExporting: isExporting ?? this.isExporting,
      results: results ?? this.results,
      summary: summary ?? this.summary,
      selectedKategori: selectedKategori ?? this.selectedKategori,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
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
    state = state.copyWith(selectedKategori: kategori);
    fetchResults();
  }

  void setPeriod(String period) {
    state = state.copyWith(selectedPeriod: period);
    fetchResults();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<void> fetchResults() async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final response = await DioClient.instance.get(
        ApiEndpoints.incentiveResults,
        queryParameters: {
          'kategori_skema': state.selectedKategori,
          'period': state.selectedPeriod,
        },
      );

      final data = response.data;
      List<IncentiveCalculationModel> items = [];
      if (data is List) {
        items = data.map((json) => IncentiveCalculationModel.fromJson(json)).toList();
      } else if (data is Map && data['data'] is List) {
        items = (data['data'] as List).map((json) => IncentiveCalculationModel.fromJson(json)).toList();
      }

      final summary = IncentiveSummaryMeta.fromCalculations(items);
      state = state.copyWith(
        isLoading: false,
        results: items,
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
