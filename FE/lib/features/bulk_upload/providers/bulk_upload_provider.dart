import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/web_downloader.dart';
import '../../../data/models/upload_batch_model.dart';
import '../../master_data/providers/master_data_provider.dart';
import '../../master_data/providers/master_target_provider.dart';

class SelectedUploadFile {
  final String name;
  final int size;
  final Uint8List bytes;

  const SelectedUploadFile({
    required this.name,
    required this.size,
    required this.bytes,
  });
}

class BulkUploadState {
  final bool isLoadingHistory;
  final bool isUploading;
  final double uploadProgress;
  final String? uploadStatusText;
  final bool isDownloadingTemplate;
  final bool isRollingBack;
  final String selectedEntity;
  final String selectedPeriod;
  final int? selectedDistributorId;
  final List<SelectedUploadFile> selectedFiles;
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
    this.uploadStatusText,
    this.isDownloadingTemplate = false,
    this.isRollingBack = false,
    this.selectedEntity = 'sellout_distributor',
    this.selectedPeriod = '',
    this.selectedDistributorId,
    this.selectedFiles = const [],
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
    String? uploadStatusText,
    bool? isDownloadingTemplate,
    bool? isRollingBack,
    String? selectedEntity,
    String? selectedPeriod,
    int? selectedDistributorId,
    bool clearDistributorId = false,
    List<SelectedUploadFile>? selectedFiles,
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
      uploadStatusText: clearFile ? null : (uploadStatusText ?? this.uploadStatusText),
      isDownloadingTemplate: isDownloadingTemplate ?? this.isDownloadingTemplate,
      isRollingBack: isRollingBack ?? this.isRollingBack,
      selectedEntity: selectedEntity ?? this.selectedEntity,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      selectedDistributorId: clearDistributorId ? null : (selectedDistributorId ?? this.selectedDistributorId),
      selectedFiles: clearFile ? const [] : (selectedFiles ?? this.selectedFiles),
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

  void setSelloutPeriod(String period) {
    state = state.copyWith(
      selectedPeriod: period.trim(),
      clearError: true,
      clearSuccess: true,
    );
  }

  void setSelloutDistributorId(int? distributorId) {
    state = state.copyWith(
      selectedDistributorId: distributorId,
      clearDistributorId: distributorId == null,
      clearError: true,
      clearSuccess: true,
    );
  }

  void setFile(String name, int size, Uint8List bytes) {
    setFiles([SelectedUploadFile(name: name, size: size, bytes: bytes)]);
  }

  void setFiles(List<SelectedUploadFile> files) {
    if (files.isEmpty) return;
    final first = files.first;
    final lower = first.name.toLowerCase();
    String? detectedEntity;
    if (lower.contains('target')) {
      detectedEntity = 'master_target_distributor';
    } else if (lower.contains('sellout') || lower.contains('sell_out')) {
      detectedEntity = 'sellout_distributor';
    } else if (lower.contains('distributor')) {
      detectedEntity = 'distributor';
    }

    final totalSize = files.fold<int>(0, (sum, f) => sum + f.size);
    state = state.copyWith(
      selectedEntity: detectedEntity ?? state.selectedEntity,
      selectedFiles: files,
      selectedFileName: files.length == 1 ? first.name : '${files.length} file dipilih (${first.name}, ...)',
      selectedFileSize: totalSize,
      selectedFileBytes: first.bytes,
      uploadProgress: 0.0,
      clearError: true,
      clearSuccess: true,
    );
  }

  void removeFileAt(int index) {
    final updated = List<SelectedUploadFile>.from(state.selectedFiles);
    if (index < 0 || index >= updated.length) return;
    updated.removeAt(index);
    if (updated.isEmpty) {
      clearSelectedFile();
    } else {
      setFiles(updated);
    }
  }

  void clearSelectedFile() {
    state = state.copyWith(clearFile: true);
  }

  Future<void> downloadTemplate({
    String? entity,
    bool withData = false,
    String? period,
    int? distributorId,
    int? depoId,
    int? brandId,
  }) async {
    final targetEntity = entity ?? state.selectedEntity;
    state = state.copyWith(isDownloadingTemplate: true, clearError: true, clearSuccess: true);
    try {
      final prefix = withData ? 'data_export' : 'template';
      final safePeriod = period != null ? period.trim().replaceAll(',', '_') : '';
      final periodSuffix = (safePeriod.isNotEmpty && safePeriod.toUpperCase() != 'ALL')
          ? '_$safePeriod'
          : (withData ? '_semua_periode' : '');
      final fileName = '${prefix}_$targetEntity$periodSuffix.xlsx';
      await WebDownloader.downloadExcel(
        ApiEndpoints.bulkUploadTemplate(targetEntity, withData: withData, period: period),
        fileName,
        queryParameters: {
          if (distributorId != null) 'distributor_id': distributorId.toString(),
          if (depoId != null) 'depo_id': depoId.toString(),
          if (brandId != null) 'brand_id': brandId.toString(),
        },
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

  Future<void> fetchHistory({String? period, int? distributorId, String? query}) async {
    state = state.copyWith(isLoadingHistory: true, clearError: true);
    try {
      final response = await DioClient.instance.get(
        ApiEndpoints.batchHistory,
        queryParameters: {
          if (period != null && period.trim().isNotEmpty) 'period': period.trim(),
          if (distributorId != null) 'distributor_id': distributorId,
          if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        },
      );
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
    final filesToUpload = state.selectedFiles.isNotEmpty
        ? state.selectedFiles
        : (state.selectedFileBytes != null && state.selectedFileName != null
            ? [SelectedUploadFile(name: state.selectedFileName!, size: state.selectedFileSize ?? 0, bytes: state.selectedFileBytes!)]
            : <SelectedUploadFile>[]);

    if (filesToUpload.isEmpty) {
      state = state.copyWith(errorMessage: 'Pilih minimal 1 file spreadsheet (.xlsx, .xls, .csv) terlebih dahulu.');
      return false;
    }

    state = state.copyWith(isUploading: true, uploadProgress: 0.05, clearError: true, clearSuccess: true);
    int totalSuccessRows = 0;
    int totalProcessedRows = 0;
    int successFiles = 0;
    final List<String> failedMessages = [];

    try {
      for (int i = 0; i < filesToUpload.length; i++) {
        final f = filesToUpload[i];
        final fileNum = i + 1;
        state = state.copyWith(
          uploadStatusText: 'Memproses file $fileNum/${filesToUpload.length}: ${f.name}...',
          uploadProgress: ((i) / filesToUpload.length).clamp(0.05, 0.95),
        );

        try {
          const int chunkSize = 512 * 1024; // 512 KB per chunk (bebas limit upload_max_filesize 2M di cPanel)
          final int totalBytes = f.bytes.length;
          final int totalChunks = (totalBytes / chunkSize).ceil().clamp(1, 100000);
          final String uploadId = '${DateTime.now().millisecondsSinceEpoch}_${i}_${f.hashCode.abs()}';
          Response? response;

          for (int c = 0; c < totalChunks; c++) {
            final int start = c * chunkSize;
            final int end = (start + chunkSize > totalBytes) ? totalBytes : start + chunkSize;
            final Uint8List slice = f.bytes.sublist(start, end);
            final String b64 = base64Encode(slice);

            state = state.copyWith(
              uploadStatusText: totalChunks > 1
                  ? 'Mengunggah ${f.name} (bagian ${c + 1}/$totalChunks)...'
                  : 'Memproses file $fileNum/${filesToUpload.length}: ${f.name}...',
              uploadProgress: ((i + ((c + 0.5) / totalChunks) * 0.95) / filesToUpload.length).clamp(0.05, 0.95),
            );

            response = await DioClient.instance.post(
              ApiEndpoints.bulkUpload(state.selectedEntity),
              data: {
                'upload_id': uploadId,
                'chunk_index': c,
                'total_chunks': totalChunks,
                'file_name': f.name,
                'chunk_base64': b64,
                'entity': state.selectedEntity,
                if (state.selectedEntity == 'sellout_distributor' && state.selectedPeriod.isNotEmpty)
                  'period': state.selectedPeriod,
                if (state.selectedEntity == 'sellout_distributor' && state.selectedDistributorId != null)
                  'distributor_id': state.selectedDistributorId,
              },
              options: Options(
                sendTimeout: const Duration(minutes: 15),
                receiveTimeout: const Duration(minutes: 15),
              ),
            );
          }

          final batchData = response?.data?['data'];
          if (batchData is Map) {
            totalProcessedRows += (batchData['total_rows'] as num?)?.toInt() ?? 0;
            totalSuccessRows += (batchData['success_rows'] as num?)?.toInt() ?? 0;
          }
          successFiles++;
        } on DioException catch (dioErr) {
          final err = ApiException.fromDioException(dioErr);
          failedMessages.add('${f.name}: ${err.message}');
        } catch (e) {
          failedMessages.add('${f.name}: $e');
        }
      }

      await fetchHistory();
      _ref?.read(masterTargetProvider.notifier).fetchTargets(force: true);
      _ref?.read(masterDataProvider.notifier).fetchAllMasterData(force: true);

      if (failedMessages.isNotEmpty && successFiles == 0) {
        state = state.copyWith(
          isUploading: false,
          uploadProgress: 0.0,
          errorMessage: failedMessages.join('\n\n'),
        );
        return false;
      }

      final summaryMsg = filesToUpload.length == 1
          ? 'Upload file ${filesToUpload.first.name} berhasil diproses ($totalSuccessRows dari $totalProcessedRows baris berhasil disimpan).'
          : '$successFiles dari ${filesToUpload.length} file berhasil diproses (Total $totalSuccessRows baris disimpan).';

      state = state.copyWith(
        isUploading: false,
        uploadProgress: 1.0,
        successMessage: summaryMsg,
        errorMessage: failedMessages.isNotEmpty ? 'Sebagian file gagal:\n${failedMessages.join('\n')}' : null,
        clearFile: failedMessages.isEmpty,
      );
      return failedMessages.isEmpty;
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
