import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../../../data/models/master_target_model.dart';

class MasterTargetState {
  final bool isLoading;
  final List<MasterTargetModel> targets;
  final List<String> availablePeriods;
  final String selectedPeriod;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int totalItems;
  final int fromItem;
  final int toItem;
  final Map<String, dynamic>? summary;
  final String? errorMessage;
  final String? successMessage;

  MasterTargetState({
    this.isLoading = false,
    this.targets = const [],
    this.availablePeriods = const ['202610'],
    this.selectedPeriod = '202610',
    this.currentPage = 1,
    this.lastPage = 1,
    this.perPage = 50,
    this.totalItems = 0,
    this.fromItem = 0,
    this.toItem = 0,
    this.summary,
    this.errorMessage,
    this.successMessage,
  });

  MasterTargetState copyWith({
    bool? isLoading,
    List<MasterTargetModel>? targets,
    List<String>? availablePeriods,
    String? selectedPeriod,
    int? currentPage,
    int? lastPage,
    int? perPage,
    int? totalItems,
    int? fromItem,
    int? toItem,
    Map<String, dynamic>? summary,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return MasterTargetState(
      isLoading: isLoading ?? this.isLoading,
      targets: targets ?? this.targets,
      availablePeriods: availablePeriods ?? this.availablePeriods,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      perPage: perPage ?? this.perPage,
      totalItems: totalItems ?? this.totalItems,
      fromItem: fromItem ?? this.fromItem,
      toItem: toItem ?? this.toItem,
      summary: summary ?? this.summary,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class MasterTargetNotifier extends StateNotifier<MasterTargetState> {
  MasterTargetNotifier() : super(MasterTargetState()) {
    init();
  }

  Future<void> init() async {
    await fetchPeriods();
    await fetchTargets();
  }

  Future<void> fetchPeriods() async {
    try {
      final res = await DioClient.instance.get(ApiEndpoints.masterTargetPeriods);
      final raw = res.data['data'] ?? res.data;
      if (raw is List) {
        final periods = raw.map((e) => e.toString()).toList();
        if (!periods.contains('202610')) {
          periods.insert(0, '202610');
        }
        final uniquePeriods = periods.toSet().toList();
        state = state.copyWith(availablePeriods: uniquePeriods);
      }
    } catch (_) {
      // Fallback tetap sediakan periode 202610
      if (!state.availablePeriods.contains('202610')) {
        state = state.copyWith(availablePeriods: ['202610']);
      }
    }
  }

  void setPeriod(String period) {
    if (state.selectedPeriod != period) {
      state = state.copyWith(selectedPeriod: period, currentPage: 1);
      fetchTargets(period: period, page: 1);
    }
  }

  Future<void> fetchTargets({
    String? period,
    String? kategori,
    int? distributorId,
    int? page,
    int? perPage,
    String? search,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final targetPeriod = period ?? state.selectedPeriod;
      final targetPage = page ?? state.currentPage;
      final targetPerPage = perPage ?? state.perPage;

      final queryParams = <String, dynamic>{
        'page': targetPage,
        'per_page': targetPerPage,
      };

      if (targetPeriod.isNotEmpty && targetPeriod != 'ALL') {
        queryParams['period'] = targetPeriod;
      }
      if (kategori != null && kategori.isNotEmpty && kategori != 'ALL') {
        queryParams['kategori_skema'] = kategori;
      }
      if (distributorId != null) {
        queryParams['distributor_id'] = distributorId;
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final res = await DioClient.instance.get(
        ApiEndpoints.masterTargets,
        queryParameters: queryParams,
      );

      final dataMap = res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : <String, dynamic>{};
      final List rawData = dataMap['data'] ?? (res.data is List ? res.data : []);
      final targets = rawData.map((e) => MasterTargetModel.fromJson(e)).toList();

      final int curPage = dataMap['current_page'] is int ? dataMap['current_page'] : (int.tryParse(dataMap['current_page']?.toString() ?? '1') ?? 1);
      final int lastPg = dataMap['last_page'] is int ? dataMap['last_page'] : (int.tryParse(dataMap['last_page']?.toString() ?? '1') ?? 1);
      final int total = dataMap['total'] is int ? dataMap['total'] : (int.tryParse(dataMap['total']?.toString() ?? '${targets.length}') ?? targets.length);
      final int from = dataMap['from'] is int ? dataMap['from'] : (int.tryParse(dataMap['from']?.toString() ?? '1') ?? (targets.isNotEmpty ? 1 : 0));
      final int to = dataMap['to'] is int ? dataMap['to'] : (int.tryParse(dataMap['to']?.toString() ?? '${targets.length}') ?? targets.length);
      final Map<String, dynamic>? summary = dataMap['summary'] is Map<String, dynamic> ? dataMap['summary'] : null;

      state = state.copyWith(
        isLoading: false,
        targets: targets,
        selectedPeriod: targetPeriod,
        currentPage: curPage,
        lastPage: lastPg,
        perPage: targetPerPage,
        totalItems: total,
        fromItem: from,
        toItem: to,
        summary: summary,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.response?.data?['message'] ?? 'Gagal memuat Master Target Kuota',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void goToPage(int page) {
    if (page >= 1 && page <= state.lastPage && page != state.currentPage) {
      fetchTargets(page: page);
    }
  }

  void setPerPage(int perPage) {
    if (state.perPage != perPage) {
      fetchTargets(page: 1, perPage: perPage);
    }
  }

  Future<bool> saveTarget({
    int? userId,
    int? distributorId,
    int? depoId,
    int? areaId,
    int? brandId,
    String? level,
    required String kategoriSkema,
    required String targetType,
    required String period,
    bool isFullYear = false,
    String? year,
    required double targetQuota,
    int? targetOutlet,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final payload = <String, dynamic>{
        'kategori_skema': kategoriSkema,
        'metrik_target': targetType,
        'target_quota': targetQuota,
      };
      if (isFullYear) {
        payload['is_full_year'] = true;
        payload['year'] = (year != null && year.trim().isNotEmpty) ? year.trim() : period.substring(0, 4);
      } else {
        payload['period'] = period;
      }
      if (userId != null) payload['user_id'] = userId;
      if (distributorId != null) payload['distributor_id'] = distributorId;
      if (depoId != null) payload['depo_id'] = depoId;
      if (areaId != null) payload['area_id'] = areaId;
      if (brandId != null) payload['brand_id'] = brandId;
      if (level != null) payload['level'] = level;
      if (targetOutlet != null) payload['target_outlet'] = targetOutlet;

      final res = await DioClient.instance.post(ApiEndpoints.masterTargets, data: payload);
      await fetchPeriods();
      await fetchTargets();

      state = state.copyWith(
        isLoading: false,
        successMessage: res.data['message'] ?? (isFullYear ? 'Target 1 tahun penuh berhasil disimpan' : 'Target berhasil disimpan'),
      );
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.response?.data?['message'] ?? 'Gagal menyimpan Master Target',
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> updateTarget({
    required int id,
    int? userId,
    int? distributorId,
    int? depoId,
    int? areaId,
    int? brandId,
    String? level,
    String? kategoriSkema,
    String? targetType,
    String? period,
    required double targetQuota,
    int? targetOutlet,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final payload = <String, dynamic>{
        'target_quota': targetQuota,
      };
      if (userId != null) payload['user_id'] = userId;
      if (distributorId != null) payload['distributor_id'] = distributorId;
      if (depoId != null) payload['depo_id'] = depoId;
      if (areaId != null) payload['area_id'] = areaId;
      if (brandId != null) payload['brand_id'] = brandId;
      if (level != null) payload['level'] = level;
      if (kategoriSkema != null) payload['kategori_skema'] = kategoriSkema;
      if (targetType != null) payload['metrik_target'] = targetType;
      if (period != null) payload['period'] = period;
      if (targetOutlet != null) payload['target_outlet'] = targetOutlet;

      await DioClient.instance.put('${ApiEndpoints.masterTargets}/$id', data: payload);
      await fetchPeriods();
      await fetchTargets();

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Target berhasil diperbarui',
      );
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.response?.data?['message'] ?? 'Gagal memperbarui Master Target',
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deleteTarget(int id) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await DioClient.instance.delete('${ApiEndpoints.masterTargets}/$id');
      await fetchPeriods();
      await fetchTargets();
      state = state.copyWith(isLoading: false, successMessage: 'Target berhasil dihapus');
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.response?.data?['message'] ?? 'Gagal menghapus Target',
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

final masterTargetProvider = StateNotifierProvider<MasterTargetNotifier, MasterTargetState>((ref) {
  return MasterTargetNotifier();
});
