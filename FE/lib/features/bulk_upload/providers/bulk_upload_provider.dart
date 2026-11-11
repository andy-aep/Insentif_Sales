import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/web_downloader.dart';
import '../../../data/models/upload_batch_model.dart';
import '../../master_data/providers/master_data_provider.dart';
import '../../master_data/providers/master_target_provider.dart';

class BulkUploadState {
  final bool isLoadingHistory;
  final bool isUploading;
  final double uploadProgress;
  final bool isDownloadingTemplate;
  final bool isRollingBack;
  final String selectedEntity;
  final Uint8List? selectedFileBytes;
  final String? selectedFileName;
  final int? selectedFileSize;
  final List<UploadBatchModel> batches;
  final String? errorMessage;
  final String? successMessage;

  BulkUploadState({
    this.isLoadingHistory = false,
    this.isUploading = false,
    this.uploadProgress = 0.0,
    this.isDownloadingTemplate = false,
    this.isRollingBack = false,
    this.selectedEntity = 'sellout_distributor',
    this.selectedFileBytes,
    this.selectedFileName,
    this.selectedFileSize,
    this.batches = const [],
    this.errorMessage,
    this.successMessage,
  });

  BulkUploadState copyWith({
    bool? isLoadingHistory,
    bool? isUploading,
    double? uploadProgress,
    bool? isDownloadingTemplate,
    bool? isRollingBack,
    String? selectedEntity,
    Uint8List? selectedFileBytes,
    String? selectedFileName,
    int? selectedFileSize,
    List<UploadBatchModel>? batches,
    String? errorMessage,
    String? successMessage,
    bool clearFile = false,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return BulkUploadState(
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      isUploading: isUploading ?? this.isUploading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      isDownloadingTemplate: isDownloadingTemplate ?? this.isDownloadingTemplate,
      isRollingBack: isRollingBack ?? this.isRollingBack,
      selectedEntity: selectedEntity ?? this.selectedEntity,
      selectedFileBytes: clearFile ? null : (selectedFileBytes ?? this.selectedFileBytes),
      selectedFileName: clearFile ? null : (selectedFileName ?? this.selectedFileName),
      selectedFileSize: clearFile ? null : (selectedFileSize ?? this.selectedFileSize),
      batches: batches ?? this.batches,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class BulkUploadNotifier extends StateNotifier<BulkUploadState> {
  final Ref? _ref;

  BulkUploadNotifier([this._ref]) : super(BulkUploadState()) {
    fetchHistory();
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void clearSuccess() {
    state = state.copyWith(clearSuccess: true);
  }

  void setEntity(String entity) {
    state = state.copyWith(
      selectedEntity: entity,
      clearError: true,
      clearSuccess: true,
    );
  }

  void setFile(String name, int size, Uint8List bytes) {
    final lower = name.toLowerCase();
    String? detectedEntity;
    if (lower.contains('target')) {
      detectedEntity = 'master_target_distributor';
    } else if (lower.contains('sellout') || lower.contains('sell_out')) {
      detectedEntity = 'sellout_distributor';
    } else if (lower.contains('distributor')) {
      detectedEntity = 'distributor';
    }

    state = state.copyWith(
      selectedEntity: detectedEntity ?? state.selectedEntity,
      selectedFileName: name,
      selectedFileSize: size,
      selectedFileBytes: bytes,
      uploadProgress: 0.0,
      clearError: true,
      clearSuccess: true,
    );
  }

  void clearSelectedFile() {
    state = state.copyWith(clearFile: true);
  }

  Future<void> downloadTemplate({String? entity, bool withData = false, String? period}) async {
    final targetEntity = entity ?? state.selectedEntity;
    state = state.copyWith(isDownloadingTemplate: true, clearError: true, clearSuccess: true);
    try {
      final prefix = withData ? 'data_export' : 'template';
      final periodSuffix = (period != null && period.isNotEmpty && period != 'ALL') ? '_$period' : '';
      final fileName = '${prefix}_$targetEntity$periodSuffix.xlsx';
      await WebDownloader.downloadExcel(
        ApiEndpoints.bulkUploadTemplate(targetEntity, withData: withData, period: period),
        fileName,
      );
      state = state.copyWith(
        isDownloadingTemplate: false,
        successMessage: withData
            ? 'Data $targetEntity berhasil ditarik ke Excel ($fileName). Anda dapat mengubahnya dan mengunggah kembali kapan saja.'
            : 'Template $fileName berhasil diunduh. Buka Sheet 2 di dalam Excel untuk melihat panduan & kode referensi.',
      );
    } on DioException catch (dioErr) {
      final err = ApiException.fromDioException(dioErr);
      state = state.copyWith(isDownloadingTemplate: false, errorMessage: err.message);
    } catch (e) {
      state = state.copyWith(isDownloadingTemplate: false, errorMessage: e.toString());
    }
  }

  Future<void> fetchHistory() async {
    state = state.copyWith(isLoadingHistory: true, clearError: true);
    try {
      final response = await DioClient.instance.get(ApiEndpoints.batchHistory);
      final data = response.data;
      List<UploadBatchModel> list = [];

      if (data is List) {
        list = data.map((j) => UploadBatchModel.fromJson(j)).toList();
      } else if (data is Map && data['data'] is List) {
        list = (data['data'] as List).map((j) => UploadBatchModel.fromJson(j)).toList();
      }

      state = state.copyWith(isLoadingHistory: false, batches: list);
    } on DioException catch (dioErr) {
      final err = ApiException.fromDioException(dioErr);
      state = state.copyWith(isLoadingHistory: false, errorMessage: err.message);
    } catch (e) {
      state = state.copyWith(isLoadingHistory: false, errorMessage: e.toString());
    }
  }

  Future<bool> upload() async {
    if (state.selectedFileBytes == null || state.selectedFileName == null) {
      state = state.copyWith(errorMessage: 'Pilih file spreadsheet (.xlsx, .xls, .csv) terlebih dahulu.');
      return false;
    }

    state = state.copyWith(isUploading: true, uploadProgress: 0.05, clearError: true, clearSuccess: true);
    try {
      final multipartFile = MultipartFile.fromBytes(
        state.selectedFileBytes!,
        filename: state.selectedFileName!,
        contentType: MediaType('application', 'vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
      );

      final formData = FormData.fromMap({
        'file': multipartFile,
        'entity': state.selectedEntity,
      });

      final response = await DioClient.instance.post(
        ApiEndpoints.bulkUpload(state.selectedEntity),
        data: formData,
        options: Options(
          sendTimeout: const Duration(minutes: 15),
          receiveTimeout: const Duration(minutes: 15),
        ),
        onSendProgress: (sent, total) {
          if (total > 0) {
            final ratio = (sent / total).clamp(0.05, 0.95);
            state = state.copyWith(uploadProgress: ratio);
          }
        },
      );

      final batchData = response.data?['data'];
      String msg = response.data?['message']?.toString() ?? 'Upload file ${state.selectedFileName} berhasil diproses.';
      if (batchData is Map) {
        final total = batchData['total_rows'] ?? 0;
        final success = batchData['success_rows'] ?? 0;
        final failed = batchData['failed_rows'] ?? 0;
        msg = '$msg ($success dari $total baris berhasil disimpan${failed > 0 ? ', $failed gagal' : ''}).';
      }
      state = state.copyWith(
        isUploading: false,
        uploadProgress: 1.0,
        successMessage: msg,
        clearFile: true,
      );

      await fetchHistory();
      // Auto refresh master data & targets across the application
      _ref?.read(masterTargetProvider.notifier).fetchTargets(force: true);
      _ref?.read(masterDataProvider.notifier).fetchAllMasterData(force: true);
      return true;
    } on DioException catch (dioErr) {
      final err = ApiException.fromDioException(dioErr);
      state = state.copyWith(isUploading: false, uploadProgress: 0.0, errorMessage: err.message);
      return false;
    } catch (e) {
      state = state.copyWith(isUploading: false, uploadProgress: 0.0, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> rollback(String batchId) async {
    state = state.copyWith(isRollingBack: true, clearError: true, clearSuccess: true);
    try {
      final response = await DioClient.instance.post(ApiEndpoints.rollbackBatch(batchId));
      final msg = response.data?['message'] ?? 'Batch $batchId berhasil di-rollback.';

      state = state.copyWith(
        isRollingBack: false,
        successMessage: msg.toString(),
      );

      await fetchHistory();
      // Auto refresh master data & targets across the application
      _ref?.read(masterTargetProvider.notifier).fetchTargets(force: true);
      _ref?.read(masterDataProvider.notifier).fetchAllMasterData(force: true);
      return true;
    } on DioException catch (dioErr) {
      final err = ApiException.fromDioException(dioErr);
      state = state.copyWith(isRollingBack: false, errorMessage: err.message);
      return false;
    } catch (e) {
      state = state.copyWith(isRollingBack: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> downloadBatchFile(String batchId, String fileName) async {
    state = state.copyWith(clearError: true, clearSuccess: true);
    try {
      await WebDownloader.downloadExcel(
        ApiEndpoints.downloadBatchFile(batchId),
        fileName,
      );
      state = state.copyWith(
        successMessage: 'File $fileName berhasil diunduh kembali.',
      );
    } on DioException catch (dioErr) {
      final err = ApiException.fromDioException(dioErr);
      state = state.copyWith(errorMessage: err.message);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<bool> deleteBatch(String batchId) async {
    state = state.copyWith(isRollingBack: true, clearError: true, clearSuccess: true);
    try {
      final response = await DioClient.instance.delete(ApiEndpoints.deleteBatch(batchId));
      final msg = response.data?['message'] ?? 'Batch $batchId berhasil dihapus permanen.';

      state = state.copyWith(
        isRollingBack: false,
        successMessage: msg.toString(),
      );

      await fetchHistory();
      // Auto refresh master data & targets across the application
      _ref?.read(masterTargetProvider.notifier).fetchTargets(force: true);
      _ref?.read(masterDataProvider.notifier).fetchAllMasterData(force: true);
      return true;
    } on DioException catch (dioErr) {
      final err = ApiException.fromDioException(dioErr);
      state = state.copyWith(isRollingBack: false, errorMessage: err.message);
      return false;
    } catch (e) {
      state = state.copyWith(isRollingBack: false, errorMessage: e.toString());
      return false;
    }
  }
}

final bulkUploadProvider = StateNotifierProvider<BulkUploadNotifier, BulkUploadState>((ref) {
  return BulkUploadNotifier(ref);
});
