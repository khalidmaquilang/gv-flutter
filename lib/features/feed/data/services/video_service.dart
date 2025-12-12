import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../auth/data/models/user_model.dart';
import '../models/comment_model.dart';
import '../models/video_model.dart';

class VideoService {
  final Dio _dio;

  VideoService({Dio? dio}) : _dio = dio ?? Dio();

  Future<List<Video>> getFeed() async {
    try {
      final _ = await _dio.get(ApiConstants.baseUrl + ApiConstants.videos);

      // Mock data if 404/error for demo
      // return (response.data as List).map((e) => Video.fromJson(e)).toList();

      // Returning Mock Data for now as backend might not be ready
      return _getMockVideos();
    } catch (e) {
      // Fallback to mock data
      return _getMockVideos();
    }
  }

  Future<bool> likeVideo(int videoId) async {
    try {
      await _dio.post('${ApiConstants.baseUrl}/videos/$videoId/like');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> unlikeVideo(int videoId) async {
    try {
      await _dio.post('${ApiConstants.baseUrl}/videos/$videoId/unlike');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Comment>> getComments(int videoId) async {
    // Mock comments
    await Future.delayed(const Duration(milliseconds: 500));
    return List.generate(
      10,
      (index) => Comment(
        id: index,
        user: User(
          id: index,
          name: "User $index",
          email: "test@test.com",
          avatar: "https://dummyimage.com/50",
        ),
        text: "This is comment #$index",
        createdAt: DateTime.now().subtract(Duration(minutes: index)),
      ),
    );
  }

  Future<Comment> postComment(int videoId, String text) async {
    // Mock response
    await Future.delayed(const Duration(milliseconds: 500));
    return Comment(
      id: 999,
      user: User(
        id: 1,
        name: "Me",
        email: "me@test.com",
        avatar: "https://dummyimage.com/50",
      ),
      text: text,
      createdAt: DateTime.now(),
    );
  }

  List<Video> _getMockVideos() {
    return List.generate(
      5,
      (index) => Video(
        id: index,
        videoUrl:
            'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
        thumbnailUrl: 'https://dummyimage.com/150',
        caption: 'Video $index #fyp',
        likesCount: 100 + index,
        commentsCount: 20 + index,
        isLiked: false,
        user: User(
          id: 1,
          name: 'User $index',
          email: 'test@test.com',
          avatar: 'https://dummyimage.com/50',
        ),
      ),
    );
  }
}
