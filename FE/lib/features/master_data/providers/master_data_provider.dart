import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../../../data/models/master_model.dart';

class MasterDataState {
  final bool isLoading;
  final List<RegionModel> regions;
  final List<DistributorModel> distributors;
  final List<DepoModel> depos;
  final List<AreaModel> areas;
  final List<BrandModel> brands;
  final String? errorMessage;
  final String? successMessage;

  MasterDataState({
    this.isLoading = false,
    this.regions = const [],
    this.distributors = const [],
    this.depos = const [],
    this.areas = const [],
    this.brands = const [],
    this.errorMessage,
    this.successMessage,
  });

  MasterDataState copyWith({
    bool? isLoading,
    List<RegionModel>? regions,
    List<DistributorModel>? distributors,
    List<DepoModel>? depos,
    List<AreaModel>? areas,
    List<BrandModel>? brands,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return MasterDataState(
      isLoading: isLoading ?? this.isLoading,
      regions: regions ?? this.regions,
      distributors: distributors ?? this.distributors,
      depos: depos ?? this.depos,
      areas: areas ?? this.areas,
      brands: brands ?? this.brands,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class MasterDataNotifier extends StateNotifier<MasterDataState> {
  MasterDataNotifier() : super(MasterDataState()) {
    fetchAllMasterData();
  }

  Future<void> fetchAllMasterData() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final responses = await Future.wait([
        DioClient.instance.get(ApiEndpoints.regions).catchError((_) => Response(requestOptions: RequestOptions())),
        DioClient.instance.get(ApiEndpoints.distributors).catchError((_) => Response(requestOptions: RequestOptions())),
        DioClient.instance.get(ApiEndpoints.depos).catchError((_) => Response(requestOptions: RequestOptions())),
        DioClient.instance.get(ApiEndpoints.areas).catchError((_) => Response(requestOptions: RequestOptions())),
        DioClient.instance.get(ApiEndpoints.brands).catchError((_) => Response(requestOptions: RequestOptions())),
      ]);

      List<RegionModel> regions = _extractList(responses[0].data, (j) => RegionModel.fromJson(j));
      List<DistributorModel> distributors = _extractList(responses[1].data, (j) => DistributorModel.fromJson(j));
      List<DepoModel> depos = _extractList(responses[2].data, (j) => DepoModel.fromJson(j));
      List<AreaModel> areas = _extractList(responses[3].data, (j) => AreaModel.fromJson(j));
      List<BrandModel> brands = _extractList(responses[4].data, (j) => BrandModel.fromJson(j));

      state = state.copyWith(
        isLoading: false,
        regions: regions,
        distributors: distributors,
        depos: depos,
        areas: areas,
        brands: brands,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> saveDistributor({
    int? id,
    required String code,
    required String name,
    int? regionId,
    List<Map<String, dynamic>>? depos,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final payload = {
        'code': code,
        'name': name,
        'region_id': regionId,
        if (depos != null) 'depos': depos,
      };
      if (id != null) {
        await DioClient.instance.put('${ApiEndpoints.distributors}/$id', data: payload);
      } else {
        await DioClient.instance.post(ApiEndpoints.distributors, data: payload);
      }
      await fetchAllMasterData();
      state = state.copyWith(
        isLoading: false,
        successMessage: id != null ? 'Distributor berhasil diperbarui' : 'Distributor berhasil ditambahkan',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal menyimpan distributor: $e');
      return false;
    }
  }

  Future<bool> saveRegion({
    int? id,
    required String code,
    required String name,
    String? description,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final payload = {
        'code': code,
        'name': name,
        if (description != null) 'description': description,
      };
      if (id != null) {
        await DioClient.instance.put('${ApiEndpoints.regions}/$id', data: payload);
      } else {
        await DioClient.instance.post(ApiEndpoints.regions, data: payload);
      }
      await fetchAllMasterData();
      state = state.copyWith(
        isLoading: false,
        successMessage: id != null ? 'Region berhasil diperbarui' : 'Region berhasil ditambahkan',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal menyimpan region: $e');
      return false;
    }
  }

  Future<bool> deleteRegion(int id) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await DioClient.instance.delete('${ApiEndpoints.regions}/$id');
      await fetchAllMasterData();
      state = state.copyWith(isLoading: false, successMessage: 'Region berhasil dihapus');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal menghapus region: $e');
      return false;
    }
  }

  Future<bool> deleteDistributor(int id) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await DioClient.instance.delete('${ApiEndpoints.distributors}/$id');
      await fetchAllMasterData();
      state = state.copyWith(isLoading: false, successMessage: 'Distributor berhasil dihapus');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal menghapus distributor: $e');
      return false;
    }
  }

  Future<bool> saveDepo({
    int? id,
    required int distributorId,
    required String code,
    required String name,
    List<Map<String, dynamic>>? areas,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final payload = {
        'distributor_id': distributorId,
        'code': code,
        'name': name,
        if (areas != null) 'areas': areas,
      };
      if (id != null) {
        await DioClient.instance.put('${ApiEndpoints.depos}/$id', data: payload);
      } else {
        await DioClient.instance.post(ApiEndpoints.depos, data: payload);
      }
      await fetchAllMasterData();
      state = state.copyWith(
        isLoading: false,
        successMessage: id != null ? 'Depo berhasil diperbarui' : 'Depo berhasil ditambahkan',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal menyimpan depo: $e');
      return false;
    }
  }

  Future<bool> deleteDepo(int id) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await DioClient.instance.delete('${ApiEndpoints.depos}/$id');
      await fetchAllMasterData();
      state = state.copyWith(isLoading: false, successMessage: 'Depo berhasil dihapus');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal menghapus depo: $e');
      return false;
    }
  }

  Future<bool> saveArea({
    int? id,
    required int depoId,
    required String code,
    required String name,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final payload = {
        'depo_id': depoId,
        'code': code,
        'name': name,
      };
      if (id != null) {
        await DioClient.instance.put('${ApiEndpoints.areas}/$id', data: payload);
      } else {
        await DioClient.instance.post(ApiEndpoints.areas, data: payload);
      }
      await fetchAllMasterData();
      state = state.copyWith(
        isLoading: false,
        successMessage: id != null ? 'Area berhasil diperbarui' : 'Area berhasil ditambahkan',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal menyimpan area: $e');
      return false;
    }
  }

  Future<bool> deleteArea(int id) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await DioClient.instance.delete('${ApiEndpoints.areas}/$id');
      await fetchAllMasterData();
      state = state.copyWith(isLoading: false, successMessage: 'Area berhasil dihapus');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal menghapus area: $e');
      return false;
    }
  }

  Future<bool> saveBrand({
    int? id,
    required String code,
    required String name,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final payload = {'code': code, 'name': name};
      if (id != null) {
        await DioClient.instance.put('${ApiEndpoints.brands}/$id', data: payload);
      } else {
        await DioClient.instance.post(ApiEndpoints.brands, data: payload);
      }
      await fetchAllMasterData();
      state = state.copyWith(
        isLoading: false,
        successMessage: id != null ? 'Brand berhasil diperbarui' : 'Brand berhasil ditambahkan',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal menyimpan brand: $e');
      return false;
    }
  }

  Future<bool> deleteBrand(int id) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await DioClient.instance.delete('${ApiEndpoints.brands}/$id');
      await fetchAllMasterData();
      state = state.copyWith(isLoading: false, successMessage: 'Brand berhasil dihapus');
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal menghapus brand: $e');
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

final masterDataProvider = StateNotifierProvider<MasterDataNotifier, MasterDataState>((ref) {
  return MasterDataNotifier();
});
