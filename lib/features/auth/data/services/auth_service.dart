import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/user_model.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final ApiClient _apiClient;
  final _storage = const FlutterSecureStorage();

  AuthService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<User> login(String email, String password) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.login,
        data: {'email': email, 'password': password},
      );

      // User reported response.data is the token string directly
      final token = response.data.toString();
      await _storage.write(key: 'auth_token', value: token);

      // Set auth header for future requests
      _apiClient.setToken(token);

      // Fetch user details
      final userResponse = await _apiClient.get(ApiConstants.user);
      return User.fromJson(userResponse.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<String> register(
    String name,
    String email,
    String password,
    String passwordConfirmation,
  ) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.register,
        data: {
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
      );
      return response.data['message']?.toString() ??
          'Please check your email for verification link.';
    } catch (e) {
      rethrow;
    }
  }

  Future<String> forgotPassword(String email) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.forgotPassword,
        data: {'email': email},
      );
      return response.data['message']?.toString() ?? 'Password reset link sent';
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
    _apiClient.clearToken();
  }

  Future<User?> restoreSession() async {
    try {
      final token = await _storage
          .read(key: 'auth_token')
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              return null;
            },
          );

      if (token == null) return null;

      _apiClient.setToken(token);
      final response = await _apiClient.get(ApiConstants.user);
      return User.fromJson(response.data);
    } catch (e) {
      // If token is invalid, expired, or storage fails, clear it and return null
      await logout();
      return null;
    }
  }
}
