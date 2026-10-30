class UploadBatchModel {
  final String id;
  final String entity;
  final int totalRows;
  final int successRows;
  final int failedRows;
  final String status; // COMPLETED, ROLLED_BACK, PROCESSING, FAILED
  final String? errorMessage;
  final String createdAt;
  final String? originalFilename;

  UploadBatchModel({
    required this.id,
    required this.entity,
    required this.totalRows,
    required this.successRows,
    required this.failedRows,
    required this.status,
    this.errorMessage,
    required this.createdAt,
    this.originalFilename,
  });

  factory UploadBatchModel.fromJson(Map<String, dynamic> json) {
    return UploadBatchModel(
      id: json['id']?.toString() ?? json['batch_id']?.toString() ?? '',
      entity: (json['entity_type'] ?? json['entity'] ?? '').toString(),
      totalRows: json['total_rows'] is int ? json['total_rows'] : int.tryParse(json['total_rows']?.toString() ?? '0') ?? 0,
      successRows: json['success_rows'] is int ? json['success_rows'] : int.tryParse(json['success_rows']?.toString() ?? '0') ?? 0,
      failedRows: json['failed_rows'] is int ? json['failed_rows'] : int.tryParse(json['failed_rows']?.toString() ?? '0') ?? 0,
      status: json['status']?.toString().toUpperCase() ?? 'COMPLETED',
      errorMessage: json['error_message']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      originalFilename: (json['file_name'] ?? json['original_filename'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'entity': entity,
    'total_rows': totalRows,
    'success_rows': successRows,
    'failed_rows': failedRows,
    'status': status,
    'error_message': errorMessage,
    'created_at': createdAt,
    'original_filename': originalFilename,
  };
}
