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
    print("getProfile called with userId: $userId");
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token != null) {
        _apiClient.setToken(token);
      }

      final url = '/users/$userId';

      final response = await _apiClient.get(url);

      return User.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<User> getCurrentUser() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token != null) {
        _apiClient.setToken(token);
      }

      final response = await _apiClient.get(ApiConstants.user);
      return User.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, int>> getStats(
    String userId, {
    bool isCurrentUser = false,
  }) async {
    try {
      final user = isCurrentUser
          ? await getCurrentUser()
          : await getProfile(userId);

      return {
        'following': user.followingCount,
        'followers': user.followersCount,
        'likes': user.likesCount,
      };
    } catch (e) {
      // Return zeros on error
      return {'following': 0, 'followers': 0, 'likes': 0};
    }
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

  Future<List<ProfileVideo>> getUserVideos(
    String userId, {
    int page = 1,
  }) async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token != null) {
        _apiClient.setToken(token);
      }

      final response = await _apiClient.get(
        ApiConstants.userVideos(userId),
        queryParameters: {'page': page},
      );

      // FeedData::collect returns data at root level, not nested
      final data = response.data['data']['data'] as List;
      return data.map((json) => ProfileVideo.fromJson(json)).toList();
    } catch (e) {
      print('Error loading user videos: $e');
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

  Future<void> followUser(String userId) async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token != null) {
        _apiClient.setToken(token);
      }

      print('Following user: $userId');
      await _apiClient.post(ApiConstants.followUser(userId));
      print('Successfully followed user: $userId');
    } catch (e) {
      print('Error following user $userId: $e');
      rethrow;
    }
  }

  Future<void> unfollowUser(String userId) async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token != null) {
        _apiClient.setToken(token);
      }

      print('Unfollowing user: $userId');
      await _apiClient.delete(ApiConstants.unfollowUser(userId));
      print('Successfully unfollowed user: $userId');
    } catch (e) {
      print('Error unfollowing user $userId: $e');
      rethrow;
    }
  }
}
