import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../data/models/auth_user_model.dart';

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final UserModel? user;
  final String? token;
  final String? errorMessage;

  AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.user,
    this.token,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    UserModel? user,
    String? token,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      token: token ?? this.token,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState(isLoading: true)) {
    checkAuth();
  }

  Future<void> checkAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userDataStr = prefs.getString('user_data');

      if (token != null && token.isNotEmpty) {
        UserModel? user;
        if (userDataStr != null) {
          try {
            user = UserModel.fromJson(jsonDecode(userDataStr));
          } catch (_) {}
        }

        state = state.copyWith(
          isAuthenticated: true,
          token: token,
          user: user,
          isLoading: false,
        );

        // Fetch fresh profile from /me
        try {
          final response = await DioClient.instance.get(ApiEndpoints.me);
          if (response.statusCode == 200) {
            final freshUserData = response.data['user'] ?? response.data['data'] ?? response.data;
            final freshUser = UserModel.fromJson(freshUserData);
            await prefs.setString('user_data', jsonEncode(freshUser.toJson()));
            state = state.copyWith(user: freshUser);
          }
        } on DioException catch (dioErr) {
          if (dioErr.response?.statusCode == 401) {
            await prefs.remove('auth_token');
            await prefs.remove('user_data');
            state = state.copyWith(isAuthenticated: false, token: null, user: null, isLoading: false);
          }
        } catch (_) {
          // If /me fails due to connection but token exists, keep authenticated with cached user
        }
      } else {
        state = state.copyWith(isAuthenticated: false, isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isAuthenticated: false, isLoading: false);
    }
  }

  Future<bool> login(String identifier, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await DioClient.instance.post(
        ApiEndpoints.login,
        data: {
          'username': identifier,
          'email': identifier,
          'password': password,
        },
      );

      final data = response.data;
      String? token;
      UserModel? user;

      if (data is Map<String, dynamic>) {
        token = data['token'] ?? data['access_token'] ?? data['data']?['token'];
        final userData = data['user'] ?? data['data']?['user'] ?? data['data'];
        if (userData is Map<String, dynamic>) {
          user = UserModel.fromJson(userData);
        }
      }

      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        if (user != null) {
          await prefs.setString('user_data', jsonEncode(user.toJson()));
        }

        state = state.copyWith(
          isAuthenticated: true,
          isLoading: false,
          token: token,
          user: user,
          clearError: true,
        );
        return true;
      } else {
        throw ApiException(message: 'Respons otentikasi tidak mengandung token yang valid.');
      }
    } on DioException catch (dioErr) {
      final apiErr = ApiException.fromDioException(dioErr);
      state = state.copyWith(
        isLoading: false,
        errorMessage: apiErr.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<String?> changeOwnPassword(String currentPassword, String newPassword) async {
    try {
      final res = await DioClient.instance.post(
        ApiEndpoints.changePassword,
        data: {
          'current_password': currentPassword,
          'password': newPassword,
        },
      );
      final msg = res.data is Map && res.data['message'] != null
          ? res.data['message'].toString()
          : 'Kata sandi berhasil diperbarui';
      return msg;
    } on DioException catch (dioErr) {
      if (dioErr.response?.data is Map) {
        final data = dioErr.response!.data as Map;
        if (data['errors'] is Map) {
          final errMap = data['errors'] as Map;
          final firstKey = errMap.keys.firstOrNull;
          if (firstKey != null && errMap[firstKey] is List) {
            return (errMap[firstKey] as List).join(', ');
          }
        }
        if (data['message'] != null) {
          return data['message'].toString();
        }
      }
      return 'Gagal mengubah kata sandi: ${dioErr.message}';
    } catch (e) {
      return 'Terjadi kesalahan: $e';
    }
  }

  Future<void> logout({bool remote = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (remote && token != null && token.isNotEmpty) {
      try {
        await DioClient.instance.post(ApiEndpoints.logout);
      } catch (_) {}
    }

    await prefs.remove('auth_token');
    await prefs.remove('user_data');

    state = AuthState(isAuthenticated: false, isLoading: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
