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
  final List<IndustriBreakdownCardModel> industriCards;
  final IndustriSummaryMeta? industriSummary;
  final List<SurabayaBreakdownCardModel> surabayaCards;
  final SurabayaSummaryMeta? surabayaSummary;
  final bool isBreakdownView;
  final IncentiveSummaryMeta summary;
  final String selectedKategori;
  final String selectedPeriod;
  final List<String> availablePeriods;

  List<String> get selectedPeriods => selectedPeriod
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
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
    this.industriCards = const [],
    this.industriSummary,
    this.surabayaCards = const [],
    this.surabayaSummary,
    this.isBreakdownView = true,
    required this.summary,
    this.selectedKategori = 'KONSUMSI',
    this.selectedPeriod = '202610',
    this.availablePeriods = const ['202610'],
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
    List<IndustriBreakdownCardModel>? industriCards,
    IndustriSummaryMeta? industriSummary,
    List<SurabayaBreakdownCardModel>? surabayaCards,
    SurabayaSummaryMeta? surabayaSummary,
    bool? isBreakdownView,
    IncentiveSummaryMeta? summary,
    String? selectedKategori,
    String? selectedPeriod,
    List<String>? availablePeriods,
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
      industriCards: industriCards ?? this.industriCards,
      industriSummary: industriSummary ?? this.industriSummary,
      surabayaCards: surabayaCards ?? this.surabayaCards,
      surabayaSummary: surabayaSummary ?? this.surabayaSummary,
      isBreakdownView: isBreakdownView ?? this.isBreakdownView,
      summary: summary ?? this.summary,
      selectedKategori: selectedKategori ?? this.selectedKategori,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      availablePeriods: availablePeriods ?? this.availablePeriods,
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
    fetchAvailablePeriods();
    fetchResults();
  }

  Future<void> fetchAvailablePeriods() async {
    try {
      final res = await DioClient.instance.get(ApiEndpoints.masterTargetPeriods);
      final raw = res.data is List
          ? res.data as List
          : (res.data is Map && res.data['data'] is List ? res.data['data'] as List : []);
      final periods = raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
      for (final sp in state.selectedPeriods) {
        if (sp.length == 6 && !periods.contains(sp)) {
          periods.add(sp);
        }
      }
      periods.sort((a, b) => b.compareTo(a));
      state = state.copyWith(availablePeriods: periods);
    } catch (_) {
      // Abaikan jika gagal memuat periode
    }
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

  void setPeriods(List<String> periods) {
    final clean = periods
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    if (clean.isEmpty) return;
    final joined = clean.join(',');
    state = state.copyWith(selectedPeriod: joined);
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

      IncentiveSummaryMeta summary = IncentiveSummaryMeta.fromCalculations(items);

      // 2. Fetch Hierarchical Distributor Breakdown Cards if KONSUMSI or Industri Audit Cards if INDUSTRI
      List<DistributorBreakdownCardModel> breakdownCards = [];
      List<IndustriBreakdownCardModel> industriCards = [];
      IndustriSummaryMeta? industriSummary;
      List<SurabayaBreakdownCardModel> surabayaCards = [];
      SurabayaSummaryMeta? surabayaSummary;

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
          final meta = breakdownRes.data?['meta'];
          if (meta is Map<String, dynamic>) {
            double toD(dynamic v) => v is num ? v.toDouble() : (double.tryParse('${v ?? ''}') ?? 0.0);
            int toI(dynamic v) => v is num ? v.toInt() : (int.tryParse('${v ?? ''}') ?? 0);
            final targetSi = toD(meta['total_target_sell_in']);
            final realSi = toD(meta['total_real_sell_in']);
            final targetSo = toD(meta['total_target_sell_out']);
            final realSo = toD(meta['total_real_sell_out']);
            final role = (meta['user_role'] ?? '').toString().toUpperCase();
            final isSpvScope = role == 'SPV' || role == 'ASC';
            final totalQuota = isSpvScope ? targetSo : (targetSi + targetSo);
            final totalReal = isSpvScope ? realSo : (realSi + realSo);
            final totalRew = toD(meta['total_reward']);
            final totalPers = toI(meta['total_personil']);
            summary = IncentiveSummaryMeta(
              totalPersonil: totalPers > 0 ? totalPers : summary.totalPersonil,
              totalQuota: totalQuota > 0 ? totalQuota : summary.totalQuota,
              totalRealization: totalReal > 0 ? totalReal : summary.totalRealization,
              totalReward: totalRew > 0 ? totalRew : summary.totalReward,
              avgAchievement: totalQuota > 0 ? (totalReal / totalQuota) * 100.0 : summary.avgAchievement,
            );
          }
        } catch (_) {}
      } else if (state.selectedKategori == 'INDUSTRI') {
        try {
          final indRes = await DioClient.instance.get(
            ApiEndpoints.incentiveIndustriBreakdown,
            queryParameters: {
              'period': state.selectedPeriod,
              if (state.selectedPositionId != null) 'position_id': state.selectedPositionId,
              if (state.selectedUserId != null) 'user_id': state.selectedUserId,
            },
          );
          final rawCards = indRes.data?['data'] as List? ?? [];
          industriCards = rawCards
              .map((c) => IndustriBreakdownCardModel.fromJson(c as Map<String, dynamic>))
              .toList();
          if (indRes.data?['meta'] is Map<String, dynamic>) {
            industriSummary = IndustriSummaryMeta.fromJson(indRes.data['meta'] as Map<String, dynamic>);
          }
        } catch (_) {}
      } else if (state.selectedKategori == 'SURABAYA') {
        try {
          final sbyRes = await DioClient.instance.get(
            ApiEndpoints.incentiveSurabayaBreakdown,
            queryParameters: {
              'period': state.selectedPeriod,
              if (state.selectedPositionId != null) 'position_id': state.selectedPositionId,
              if (state.selectedUserId != null) 'user_id': state.selectedUserId,
            },
          );
          final rawCards = sbyRes.data?['data'] as List? ?? [];
          surabayaCards = rawCards
              .map((c) => SurabayaBreakdownCardModel.fromJson(c as Map<String, dynamic>))
              .toList();
          if (sbyRes.data?['meta'] is Map<String, dynamic>) {
            surabayaSummary = SurabayaSummaryMeta.fromJson(sbyRes.data['meta'] as Map<String, dynamic>);
          }
        } catch (_) {}
      }

      state = state.copyWith(
        isLoading: false,
        results: items,
        breakdownCards: breakdownCards,
        industriCards: industriCards,
        industriSummary: industriSummary,
        surabayaCards: surabayaCards,
        surabayaSummary: surabayaSummary,
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
      await exportExcel();
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
      final safePeriod = state.selectedPeriod.replaceAll(',', '_');
      final filename = 'Insentif_${state.selectedKategori}_$safePeriod.xlsx';
      await WebDownloader.downloadExcel(
        ApiEndpoints.exportExcel,
        filename,
        queryParameters: {
          'kategori_skema': state.selectedKategori,
          'period': state.selectedPeriod,
          if (state.selectedPositionId != null) 'position_id': state.selectedPositionId.toString(),
          if (state.selectedUserId != null) 'user_id': state.selectedUserId.toString(),
          if (state.searchQuery.trim().isNotEmpty) 'search': state.searchQuery.trim(),
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
