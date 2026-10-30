import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../../../data/models/master_model.dart';

class SalesAssignmentState {
  final bool isLoading;
  final List<SalesDistributorAssignmentModel> distributorAssignments;
  final List<SurabayaAssignmentModel> surabayaAssignments;
  final String? errorMessage;
  final String? successMessage;

  SalesAssignmentState({
    this.isLoading = false,
    this.distributorAssignments = const [],
    this.surabayaAssignments = const [],
    this.errorMessage,
    this.successMessage,
  });

  SalesAssignmentState copyWith({
    bool? isLoading,
    List<SalesDistributorAssignmentModel>? distributorAssignments,
    List<SurabayaAssignmentModel>? surabayaAssignments,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return SalesAssignmentState(
      isLoading: isLoading ?? this.isLoading,
      distributorAssignments: distributorAssignments ?? this.distributorAssignments,
      surabayaAssignments: surabayaAssignments ?? this.surabayaAssignments,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class SalesAssignmentNotifier extends StateNotifier<SalesAssignmentState> {
  SalesAssignmentNotifier() : super(SalesAssignmentState()) {
    fetchAllAssignments();
  }

  Future<void> fetchAllAssignments() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final resDist = await DioClient.instance.get(ApiEndpoints.salesDistributorAssignments);
      final resSby = await DioClient.instance.get(ApiEndpoints.salesSurabayaAssignments);

      final distList = _extractList(resDist.data, (j) => SalesDistributorAssignmentModel.fromJson(j));
      final sbyList = _extractList(resSby.data, (j) => SurabayaAssignmentModel.fromJson(j));

      state = state.copyWith(
        isLoading: false,
        distributorAssignments: distList,
        surabayaAssignments: sbyList,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal memuat data penugasan: $e');
    }
  }

  Future<bool> saveDistributorAssignment({
    required int userId,
    int? distributorId,
    int? regionId,
    int? nsmId,
    int? lsmId,
    int? asmId,
    int? depoId,
    int? areaId,
    List<int>? lsmIds,
    String period = '202610',
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final payload = {
        'user_id': userId,
        if (distributorId != null) 'distributor_id': distributorId,
        if (regionId != null) 'region_id': regionId,
        if (nsmId != null) 'nsm_id': nsmId,
        if (lsmId != null) 'lsm_id': lsmId,
        if (asmId != null) 'asm_id': asmId,
        if (depoId != null) 'depo_id': depoId,
        if (areaId != null) 'area_id': areaId,
        if (lsmIds != null) 'lsm_ids': lsmIds,
        'period': period,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };

      await DioClient.instance.post(ApiEndpoints.salesDistributorAssignments, data: payload);
      await fetchAllAssignments();

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Penugasan Distributor & Area berhasil disimpan!',
      );
      return true;
    } on DioException catch (dioErr) {
      final serverMsg = dioErr.response?.data?['message'] ?? dioErr.message;
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal: $serverMsg');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal menyimpan penugasan: $e');
      return false;
    }
  }

  Future<bool> deleteDistributorAssignment(int id) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await DioClient.instance.delete('${ApiEndpoints.salesDistributorAssignments}/$id');
      await fetchAllAssignments();
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Penugasan Distributor berhasil dihapus',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal menghapus penugasan: $e');
      return false;
    }
  }

  Future<bool> saveSurabayaAssignment({
    required int coordinatorId,
    required int salesId,
    required String salesType,
    required String period,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final payload = {
        'coordinator_id': coordinatorId,
        'sales_id': salesId,
        'sales_type': salesType,
        'period': period,
      };

      await DioClient.instance.post(ApiEndpoints.salesSurabayaAssignments, data: payload);
      await fetchAllAssignments();

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Penugasan Sales Surabaya berhasil disimpan!',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal: $e');
      return false;
    }
  }

  Future<bool> deleteSurabayaAssignment(int id) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await DioClient.instance.delete('${ApiEndpoints.salesSurabayaAssignments}/$id');
      await fetchAllAssignments();
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Penugasan Surabaya berhasil dihapus',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal menghapus penugasan Surabaya: $e');
      return false;
    }
  }

  List<T> _extractList<T>(dynamic data, T Function(Map<String, dynamic>) mapper) {
    if (data == null) return [];
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().map(mapper).toList();
    }
    if (data is Map && data['data'] is List) {
      return (data['data'] as List).whereType<Map<String, dynamic>>().map(mapper).toList();
    }
    return [];
  }
}

final salesAssignmentProvider = StateNotifierProvider<SalesAssignmentNotifier, SalesAssignmentState>((ref) {
  return SalesAssignmentNotifier();
});
