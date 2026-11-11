import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_endpoints.dart';

class DioClient {
  static late Dio _dio;
  static void Function()? onUnauthorized;

  static Dio get instance => _dio;

  static void init({void Function()? onAuthExpired}) {
    onUnauthorized = onAuthExpired;
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(minutes: 10),
        sendTimeout: const Duration(minutes: 15),
        receiveTimeout: const Duration(minutes: 15),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('auth_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            final path = error.requestOptions.path;
            final isAuthRoute = path.contains(ApiEndpoints.login) || path.contains(ApiEndpoints.logout);

            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('auth_token');
            await prefs.remove('user_data');

            // Hanya panggil onUnauthorized jika bukan request login/logout
            if (!isAuthRoute && onUnauthorized != null) {
              final callback = onUnauthorized;
              onUnauthorized = null; // Cegah rekursif loop
              try {
                callback!();
              } finally {
                // Pulihkan kembali setelah delay singkat
                Future.delayed(const Duration(seconds: 2), () {
                  onUnauthorized = callback;
                });
              }
            }
          }
          return handler.next(error);
        },
      ),
    );
  }
}
