import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/user_model.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final Dio _dio;
  final _storage = const FlutterSecureStorage();

  AuthService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConstants.baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );

  Future<User> login(String email, String password) async {
    try {
      final response = await _dio.post(
        ApiConstants.baseUrl + ApiConstants.login,
        data: {'email': email, 'password': password},
      );

      // User reported response.data is the token string directly
      final token = response.data.toString();
      await _storage.write(key: 'auth_token', value: token);

      // Set auth header for future requests
      _dio.options.headers['Authorization'] = 'Bearer $token';

      // Fetch user details
      final userResponse = await _dio.get(
        ApiConstants.baseUrl + ApiConstants.user,
      );
      return User.fromJson(userResponse.data);
    } catch (e) {
      throw Exception('Login Failed: $e');
    }
  }

  Future<User> register(String name, String email, String password) async {
    try {
      final response = await _dio.post(
        ApiConstants.baseUrl + ApiConstants.register,
        data: {
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': password,
        },
      );
      return User.fromJson(response.data['user']);
    } catch (e) {
      throw Exception('Registration Failed: $e');
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
    _dio.options.headers.remove('Authorization');
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

      _dio.options.headers['Authorization'] = 'Bearer $token';
      final response = await _dio.get(ApiConstants.baseUrl + ApiConstants.user);
      return User.fromJson(response.data);
    } catch (e) {
      // If token is invalid, expired, or storage fails, clear it and return null
      await logout();
      return null;
    }
  }
}
