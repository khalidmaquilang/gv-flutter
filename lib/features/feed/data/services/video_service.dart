import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../auth/data/models/user_model.dart';
import '../models/comment_model.dart';
import '../models/video_model.dart';

class VideoService {
  final ApiClient _apiClient;

  VideoService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<List<Video>> getFeed() async {
    try {
      final _ = await _apiClient.get(ApiConstants.videos);

      // Mock data if 404/error for demo
      // return (response.data as List).map((e) => Video.fromJson(e)).toList();

      // Returning Mock Data for now as backend might not be ready
      return _getMockVideos();
    } catch (e) {
      // Fallback to mock data
      return _getMockVideos();
    }
  }

  Future<bool> likeVideo(String videoId) async {
    try {
      await _apiClient.post('/videos/$videoId/like');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> unlikeVideo(String videoId) async {
    try {
      await _apiClient.post('/videos/$videoId/unlike');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Comment>> getComments(String videoId) async {
    // Mock comments
    await Future.delayed(const Duration(milliseconds: 500));
    return List.generate(
      10,
      (index) => Comment(
        id: index.toString(),
        user: User(
          id: index.toString(),
          name: "User $index",
          email: "test@test.com",
          avatar: "https://dummyimage.com/50",
        ),
        text: "This is comment #$index",
        createdAt: DateTime.now().subtract(Duration(minutes: index)),
      ),
    );
  }

  Future<Comment> postComment(String videoId, String text) async {
    // Mock response
    await Future.delayed(const Duration(milliseconds: 500));
    return Comment(
      id: "999",
      user: User(
        id: "1",
        name: "Me",
        email: "me@test.com",
        avatar: "https://dummyimage.com/50",
      ),
      text: text,
      createdAt: DateTime.now(),
    );
  }

  // In-memory storage for uploaded videos
  static final List<Video> _uploadedVideos = [];

  Future<bool> uploadVideo({
    required String videoPath,
    required String description,
    required String privacy,
    required bool allowComments,
    String? musicId,
  }) async {
    try {
      String fileName = videoPath.split('/').last;

      FormData formData = FormData.fromMap({
        "video": await MultipartFile.fromFile(videoPath, filename: fileName),
        "description": description,
        "privacy": privacy,
        "allow_comments": allowComments ? 1 : 0,
        if (musicId != null) "music_id": musicId,
      });

      final response = await _apiClient.post(
        ApiConstants.createPost,
        data: formData,
        options: Options(
          headers: {"Content-Type": "multipart/form-data"},
          sendTimeout: const Duration(minutes: 10), // Allow long uploads
          receiveTimeout: const Duration(minutes: 10), // Allow long processing
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
      return false;
    } catch (e) {
      rethrow;
    }
  }

  List<Video> _getMockVideos() {
    final mock = List.generate(
      5,
      (index) => Video(
        id: index.toString(),
        videoUrl:
            'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
        thumbnailUrl: 'https://dummyimage.com/150',
        caption: 'Video $index #fyp',
        likesCount: 100 + index,
        commentsCount: 20 + index,
        isLiked: false,
        user: User(
          id: "1",
          name: 'User $index',
          email: 'test@test.com',
          avatar: 'https://dummyimage.com/50',
        ),
      ),
    );
    // Combine uploaded videos with mock videos
    return [..._uploadedVideos, ...mock];
  }
}
