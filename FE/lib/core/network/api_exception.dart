import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors;

  ApiException({
    required this.message,
    this.statusCode,
    this.errors,
  });

  factory ApiException.fromDioException(DioException dioException) {
    String message = 'Terjadi kesalahan pada koneksi jaringan.';
    int? statusCode = dioException.response?.statusCode;
    Map<String, dynamic>? errors;

    if (dioException.response != null && dioException.response?.data != null) {
      final data = dioException.response?.data;
      if (data is Map<String, dynamic>) {
        if (data.containsKey('message') && data['message'] != null) {
          message = data['message'].toString();
        } else if (data.containsKey('error') && data['error'] != null) {
          message = data['error'].toString();
        }

        if (data.containsKey('errors') && data['errors'] is Map<String, dynamic>) {
          errors = data['errors'] as Map<String, dynamic>;
          // Append first validation error message if available
          final firstError = errors.values.first;
          if (firstError is List && firstError.isNotEmpty) {
            message = '$message: ${firstError.first}';
          }
        }
      }
    } else {
      switch (dioException.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          message = 'Waktu koneksi ke server habis (Timeout).';
          break;
        case DioExceptionType.connectionError:
          message = 'Gagal terhubung ke server Backend di ${dioException.requestOptions.uri}.';
          break;
        case DioExceptionType.cancel:
          message = 'Permintaan dibatalkan.';
          break;
        default:
          message = dioException.message ?? 'Terjadi kesalahan sistem yang tidak terduga.';
      }
    }

    return ApiException(
      message: message,
      statusCode: statusCode,
      errors: errors,
    );
  }

  @override
  String toString() => message;
}
