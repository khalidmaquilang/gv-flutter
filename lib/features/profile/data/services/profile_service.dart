import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../auth/data/models/user_model.dart';

class ProfileService {
  final Dio _dio;

  ProfileService({Dio? dio}) : _dio = dio ?? Dio();

  Future<User> getProfile(String userId) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}${ApiConstants.user}/$userId',
      );
      return User.fromJson(response.data);
    } catch (e) {
      // Mock data
      return User(
        id: userId,
        name: "User $userId",
        email: "user$userId@example.com",
        avatar: "https://dummyimage.com/150",
        bio: "TikTok Clone User\nFollow me!",
      );
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
}
