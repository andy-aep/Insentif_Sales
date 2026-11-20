import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../../../data/models/master_model.dart';

class SapIndustriCustomerModel {
  final String cardCode;
  final String cardName;
  final String city;
  final String address;
  final String phone;

  SapIndustriCustomerModel({
    required this.cardCode,
    required this.cardName,
    this.city = '',
    this.address = '',
    this.phone = '',
  });

  factory SapIndustriCustomerModel.fromJson(Map<String, dynamic> json) {
    return SapIndustriCustomerModel(
      cardCode: (json['card_code'] ?? json['CardCode'] ?? '').toString().trim(),
      cardName: (json['card_name'] ?? json['CardName'] ?? '').toString().trim(),
      city: (json['city'] ?? json['Depo'] ?? '').toString().trim(),
      address: (json['address'] ?? json['Address'] ?? '').toString().trim(),
      phone: (json['phone'] ?? json['Phone1'] ?? '').toString().trim(),
    );
  }
}

class SalesAssignmentState {
  final bool isLoading;
  final bool isLoadingSapCustomers;
  final List<SalesDistributorAssignmentModel> distributorAssignments;
  final List<SurabayaAssignmentModel> surabayaAssignments;
  final List<IndustriCustomerModel> industriCustomers;
  final List<SapIndustriCustomerModel> sapIndustriCustomers;
  final List<SalesIndustriAssignmentModel> industriAssignments;
  final String? sapCustomersError;
  final String? errorMessage;
  final String? successMessage;

  SalesAssignmentState({
    this.isLoading = false,
    this.isLoadingSapCustomers = false,
    this.distributorAssignments = const [],
    this.surabayaAssignments = const [],
    this.industriCustomers = const [],
    this.sapIndustriCustomers = const [],
    this.industriAssignments = const [],
    this.sapCustomersError,
    this.errorMessage,
    this.successMessage,
  });

  SalesAssignmentState copyWith({
    bool? isLoading,
    bool? isLoadingSapCustomers,
    List<SalesDistributorAssignmentModel>? distributorAssignments,
    List<SurabayaAssignmentModel>? surabayaAssignments,
    List<IndustriCustomerModel>? industriCustomers,
    List<SapIndustriCustomerModel>? sapIndustriCustomers,
    List<SalesIndustriAssignmentModel>? industriAssignments,
    String? sapCustomersError,
    bool clearSapCustomersError = false,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return SalesAssignmentState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingSapCustomers: isLoadingSapCustomers ?? this.isLoadingSapCustomers,
      distributorAssignments: distributorAssignments ?? this.distributorAssignments,
      surabayaAssignments: surabayaAssignments ?? this.surabayaAssignments,
      industriCustomers: industriCustomers ?? this.industriCustomers,
      sapIndustriCustomers: sapIndustriCustomers ?? this.sapIndustriCustomers,
      industriAssignments: industriAssignments ?? this.industriAssignments,
      sapCustomersError: clearSapCustomersError ? null : (sapCustomersError ?? this.sapCustomersError),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class SalesAssignmentNotifier extends StateNotifier<SalesAssignmentState> {
  bool _isFetchingAll = false;
  bool _isFetchingIndustriOnly = false;

  SalesAssignmentNotifier() : super(SalesAssignmentState()) {
    fetchAllAssignments();
  }

  Future<void> fetchAllAssignments({bool force = false}) async {
    if (_isFetchingAll) return;
    if (!force &&
        (state.distributorAssignments.isNotEmpty ||
            state.surabayaAssignments.isNotEmpty ||
            state.industriAssignments.isNotEmpty ||
            state.industriCustomers.isNotEmpty)) {
      return;
    }

    _isFetchingAll = true;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      String? firstError;
      Future<Response?> safeGet(String path) async {
        try {
          return await DioClient.instance.get(path);
        } on DioException catch (e) {
          firstError ??= (e.response?.data is Map ? e.response?.data['message']?.toString() : null) ?? e.message;
          return null;
        } catch (e) {
          firstError ??= e.toString();
          return null;
        }
      }

      final responses = await Future.wait([
        safeGet(ApiEndpoints.salesDistributorAssignments),
        safeGet(ApiEndpoints.salesSurabayaAssignments),
        safeGet(ApiEndpoints.industriCustomers),
        safeGet(ApiEndpoints.salesIndustriAssignments),
      ]);

      final distList = responses[0] != null
          ? _extractList(responses[0]!.data, (j) => SalesDistributorAssignmentModel.fromJson(j))
          : state.distributorAssignments;
      final sbyList = responses[1] != null
          ? _extractList(responses[1]!.data, (j) => SurabayaAssignmentModel.fromJson(j))
          : state.surabayaAssignments;
      final indCustList = responses[2] != null
          ? _extractList(responses[2]!.data, (j) => IndustriCustomerModel.fromJson(j))
          : state.industriCustomers;
      final indAssignList = responses[3] != null
          ? _extractList(responses[3]!.data, (j) => SalesIndustriAssignmentModel.fromJson(j))
          : state.industriAssignments;

      state = state.copyWith(
        isLoading: false,
        distributorAssignments: distList,
        surabayaAssignments: sbyList,
        industriCustomers: indCustList,
        industriAssignments: indAssignList,
        errorMessage: firstError != null && responses.every((r) => r == null)
            ? 'Gagal memuat data penugasan: $firstError'
            : null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal memuat data penugasan: $e');
    } finally {
      _isFetchingAll = false;
    }
  }

  Future<void> fetchIndustriDataOnly({bool force = false}) async {
    if (_isFetchingIndustriOnly) return;
    if (!force && (state.industriCustomers.isNotEmpty || state.industriAssignments.isNotEmpty)) {
      return;
    }

    _isFetchingIndustriOnly = true;
    try {
      final responses = await Future.wait([
        DioClient.instance.get(ApiEndpoints.industriCustomers),
        DioClient.instance.get(ApiEndpoints.salesIndustriAssignments),
      ]);

      final indCustList = _extractList(responses[0].data, (j) => IndustriCustomerModel.fromJson(j));
      final indAssignList = _extractList(responses[1].data, (j) => SalesIndustriAssignmentModel.fromJson(j));

      state = state.copyWith(
        industriCustomers: indCustList,
        industriAssignments: indAssignList,
      );
    } catch (_) {
      // Abaikan jika gagal silent load untuk modal Realisasi Industri
    } finally {
      _isFetchingIndustriOnly = false;
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
      await fetchAllAssignments(force: true);

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

  Future<bool> saveDistributorMappingBundle({
    required int distributorId,
    required String period,
    bool isFullYear = false,
    String? year,
    int? asmUserId,
    required List<Map<String, dynamic>> areas,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final payload = <String, dynamic>{
        'distributor_id': distributorId,
        'period': period,
        'is_full_year': isFullYear,
        if (year != null && year.isNotEmpty) 'year': year,
        'asm_user_id': asmUserId,
        'areas': areas,
      };
      final res = await DioClient.instance.post(ApiEndpoints.salesDistributorBulkMap, data: payload);
      await fetchAllAssignments(force: true);
      state = state.copyWith(
        isLoading: false,
        successMessage: res.data is Map
            ? (res.data['message']?.toString() ?? 'Pemetaan PIC berhasil disimpan')
            : 'Pemetaan PIC berhasil disimpan',
      );
      return true;
    } on DioException catch (dioErr) {
      final serverMsg = dioErr.response?.data is Map ? (dioErr.response?.data['message'] ?? dioErr.message) : dioErr.message;
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal: $serverMsg');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal menyimpan pemetaan PIC: $e');
      return false;
    }
  }

  Future<bool> deleteDistributorAssignment(int id) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await DioClient.instance.delete('${ApiEndpoints.salesDistributorAssignments}/$id');
      await fetchAllAssignments(force: true);
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
      await fetchAllAssignments(force: true);

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
      await fetchAllAssignments(force: true);
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

  Future<bool> saveIndustriCustomer({
    int? id,
    String? customerCode,
    required String customerName,
    String? city,
    required String customerType,
    String? firstTransactionPeriod,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final payload = {
        if (customerCode != null && customerCode.trim().isNotEmpty) 'customer_code': customerCode.trim(),
        'customer_name': customerName.trim(),
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
        'customer_type': customerType,
        if (firstTransactionPeriod != null && firstTransactionPeriod.trim().isNotEmpty)
          'first_transaction_period': firstTransactionPeriod.trim(),
      };
      if (id == null) {
        await DioClient.instance.post(ApiEndpoints.industriCustomers, data: payload);
      } else {
        await DioClient.instance.put('${ApiEndpoints.industriCustomers}/$id', data: payload);
      }
      await fetchAllAssignments(force: true);
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Customer Industri berhasil disimpan',
      );
      return true;
    } on DioException catch (dioErr) {
      final serverMsg = dioErr.response?.data?['message'] ?? dioErr.message;
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal: $serverMsg');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal menyimpan customer: $e');
      return false;
    }
  }

  Future<bool> deleteIndustriCustomer(int id) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await DioClient.instance.delete('${ApiEndpoints.industriCustomers}/$id');
      await fetchAllAssignments(force: true);
      state = state.copyWith(isLoading: false, successMessage: 'Customer Industri berhasil dihapus');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal menghapus customer: $e');
      return false;
    }
  }

  Future<void> fetchSapIndustriCustomers({bool force = false}) async {
    if (state.isLoadingSapCustomers) return;
    if (!force && state.sapIndustriCustomers.isNotEmpty) return;

    state = state.copyWith(isLoadingSapCustomers: true, clearSapCustomersError: true);
    try {
      final res = await DioClient.instance.get(ApiEndpoints.sapIndustriCustomers);
      final raw = res.data is Map && res.data['data'] is List ? res.data['data'] as List : [];
      final list = raw
          .whereType<Map<String, dynamic>>()
          .map((e) => SapIndustriCustomerModel.fromJson(e))
          .toList();
      state = state.copyWith(isLoadingSapCustomers: false, sapIndustriCustomers: list);
    } on DioException catch (dioErr) {
      final msg = dioErr.response?.data?['message']?.toString() ?? dioErr.message ?? 'Gagal memuat data SAP';
      state = state.copyWith(isLoadingSapCustomers: false, sapCustomersError: msg);
    } catch (e) {
      state = state.copyWith(isLoadingSapCustomers: false, sapCustomersError: e.toString());
    }
  }

  Future<bool> saveIndustriAssignment({
    required int userId,
    int? industriCustomerId,
    SapIndustriCustomerModel? sapCustomer,
    String customerType = 'EXISTING',
    String? period,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await DioClient.instance.post(ApiEndpoints.salesIndustriAssignments, data: {
        'user_id': userId,
        if (industriCustomerId != null) 'industri_customer_id': industriCustomerId,
        if (sapCustomer != null) ...{
          'customer_code': sapCustomer.cardCode,
          'customer_name': sapCustomer.cardName,
          if (sapCustomer.city.isNotEmpty) 'city': sapCustomer.city,
          'customer_type': customerType,
        },
        if (period != null && period.trim().isNotEmpty) 'period': period.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      });
      await fetchAllAssignments(force: true);
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Penugasan Customer & Sales Industri berhasil disimpan',
      );
      return true;
    } on DioException catch (dioErr) {
      final serverMsg = dioErr.response?.data?['message'] ?? dioErr.message;
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal: $serverMsg');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal menyimpan penugasan Industri: $e');
      return false;
    }
  }

  Future<bool> deleteIndustriAssignment(int id) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await DioClient.instance.delete('${ApiEndpoints.salesIndustriAssignments}/$id');
      await fetchAllAssignments(force: true);
      state = state.copyWith(isLoading: false, successMessage: 'Penugasan Industri berhasil dihapus');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal menghapus penugasan Industri: $e');
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
