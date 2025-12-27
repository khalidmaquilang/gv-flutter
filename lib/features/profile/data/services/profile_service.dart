import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../auth/data/models/user_model.dart';
import '../models/profile_video_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';

class ProfileService {
  final ApiClient _apiClient;
  final _storage = const FlutterSecureStorage();

  ProfileService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<User> getProfile(String userId) async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token != null) {
        _apiClient.setToken(token);
      }

      final response = await _apiClient.get('${ApiConstants.user}/$userId');
      return User.fromJson(response.data);
    } catch (e) {
      // Mock data
      return User(
        id: "019b26fa-9bcd-73f8-9890-b85b6f8f7b64",
        name: "Test User",
        username: "test",
        email: "aa@aa.com",
        avatar: "https://dummyimage.com/150",
        bio: "TikTok Clone User\nFollow me!",
      );
    }
  }

  Future<User> getCurrentUser() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token != null) {
        _apiClient.setToken(token);
      }

      final response = await _apiClient.get(ApiConstants.user);
      print(response.data);
      return User.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, int>> getStats(String userId) async {
    // Mock API call for stats
    await Future.delayed(const Duration(milliseconds: 500));
    return {'following': 105, 'followers': 5600, 'likes': 12000};
  }

  Future<void> followUser(String userId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    // API Call to follow
  }

  Future<List<ProfileVideo>> getMyVideos({int page = 1}) async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token != null) {
        _apiClient.setToken(token);
      }

      final response = await _apiClient.get(
        ApiConstants.myVideos,
        queryParameters: {'page': page},
      );

      final data = response.data['data']['data'] as List;
      return data.map((json) => ProfileVideo.fromJson(json)).toList();
    } catch (e) {
      // Return empty list on error for now
      return [];
    }
  }

  Future<User> updateProfile({
    String? name,
    String? username,
    String? bio,
  }) async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token != null) {
        _apiClient.setToken(token);
      }

      final data = <String, dynamic>{};
      if (name != null && name.isNotEmpty) data['name'] = name;
      if (username != null && username.isNotEmpty) data['username'] = username;
      if (bio != null && bio.isNotEmpty) data['bio'] = bio;

      final response = await _apiClient.put(
        ApiConstants.updateProfile,
        data: data,
      );

      return User.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<User> uploadProfileImage(String imagePath) async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token != null) {
        _apiClient.setToken(token);
      }

      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(imagePath),
      });

      final response = await _apiClient.post(
        ApiConstants.uploadProfileAvatar,
        data: formData,
      );

      return User.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }
}
