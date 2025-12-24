import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../auth/data/models/user_model.dart';
import '../models/comment_model.dart';
import '../models/video_model.dart';

class VideoService {
  final ApiClient _apiClient;

  VideoService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<FeedResponse> getFeed({String? cursor}) async {
    try {
      final endpoint = cursor != null
          ? "${ApiConstants.feed}?cursor=$cursor"
          : ApiConstants.feed;

      final response = await _apiClient.get(endpoint);
      print(response);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as List;
        final videos = data.map((e) => Video.fromJson(e)).toList();
        final nextCursor = response.data['next_cursor'] as String?;

        return FeedResponse(videos: videos, nextCursor: nextCursor);
      }

      return FeedResponse(videos: _getMockVideos(), nextCursor: null);
    } catch (e) {
      // Fallback to mock data
      return FeedResponse(videos: _getMockVideos(), nextCursor: null);
    }
  }

  Future<bool> toggleReaction(String videoId) async {
    try {
      await _apiClient.post('/feeds/$videoId/react');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<CommentResponse> getComments(String videoId, {String? cursor}) async {
    try {
      final endpoint = cursor != null
          ? "/feeds/$videoId/comments?cursor=$cursor"
          : "/feeds/$videoId/comments";

      final response = await _apiClient.get(endpoint);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as List;
        final comments = data.map((e) => Comment.fromJson(e)).toList();
        final nextCursor = response.data['next_cursor'] as String?;

        return CommentResponse(comments: comments, nextCursor: nextCursor);
      }
      return CommentResponse(comments: [], nextCursor: null);
    } catch (e) {
      print("Get Comments Error: $e");
      return CommentResponse(comments: [], nextCursor: null);
    }
  }

  Future<String> postComment(String videoId, String text) async {
    try {
      final response = await _apiClient.post(
        "/feeds/$videoId/comments",
        data: {"message": text},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Return the ID for future reference
        return response.data['id'].toString();
      }
      throw Exception('Failed to post comment');
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> toggleCommentReaction(String commentId) async {
    try {
      await _apiClient.post('/comments/$commentId/react');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> recordView(String videoId) async {
    try {
      await _apiClient.post('/feeds/$videoId/view');
      return true;
    } catch (e) {
      // Fail silently, views are best-effort
      return false;
    }
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

class FeedResponse {
  final List<Video> videos;
  final String? nextCursor;

  FeedResponse({required this.videos, this.nextCursor});
}

class CommentResponse {
  final List<Comment> comments;
  final String? nextCursor;

  CommentResponse({required this.comments, this.nextCursor});
}
