import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/video_model.dart';
import '../../data/services/video_service.dart';
import '../../../auth/data/models/user_model.dart';

import '../../../../core/providers/api_provider.dart';

final videoServiceProvider = Provider((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return VideoService(apiClient: apiClient);
});

final feedProvider = AsyncNotifierProvider<FeedNotifier, List<Video>>(
  FeedNotifier.new,
);

final followingFeedProvider =
    AsyncNotifierProvider<FollowingFeedNotifier, List<Video>>(
      FollowingFeedNotifier.new,
    );

class FeedNotifier extends AsyncNotifier<List<Video>> {
  String? _nextCursor;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  Future<List<Video>> build() async {
    return _fetchFirstPage();
  }

  Future<List<Video>> _fetchFirstPage() async {
    final service = ref.read(videoServiceProvider);
    final response = await service.getFeed();
    _nextCursor = response.nextCursor;
    _hasMore = _nextCursor != null;

    // Dummy Video for Zoom Testing
    final dummyVideo = Video(
      id: "99999", // String
      user: User(id: "1", name: 'TestUser', email: 'test@test.com'),
      videoUrl:
          'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
      thumbnailUrl: '',
      caption: 'Zoom Test Video (Dummy)',
      likesCount: 999,

      isLiked: false,
    );

    return [dummyVideo, ...response.videos];
  }

  Future<void> loadNextPage() async {
    if (!_hasMore || _isLoadingMore) return;

    _isLoadingMore = true;
    try {
      final service = ref.read(videoServiceProvider);
      final response = await service.getFeed(cursor: _nextCursor);

      _nextCursor = response.nextCursor;
      _hasMore = _nextCursor != null;

      final currentVideos = state.value ?? [];
      state = AsyncData([...currentVideos, ...response.videos]);
    } catch (e) {
      // Keep old state but maybe show error?
      // For now silent failure on pagination
      print("Pagination error: $e");
    } finally {
      _isLoadingMore = false;
    }
  }

  void toggleLike(String videoId) {
    if (state.value == null) return;

    final currentVideos = state.value!;
    final index = currentVideos.indexWhere((v) => v.id == videoId);

    if (index != -1) {
      final originalVideo = currentVideos[index];
      final newIsLiked = !originalVideo.isLiked;
      final newLikesCount = originalVideo.likesCount + (newIsLiked ? 1 : -1);

      final updatedVideo = originalVideo.copyWith(
        isLiked: newIsLiked,
        likesCount: newLikesCount,
      );

      final List<Video> updatedList = List.from(currentVideos);
      updatedList[index] = updatedVideo;

      state = AsyncData(updatedList);
    }
  }
}

class FollowingFeedNotifier extends AsyncNotifier<List<Video>> {
  String? _nextCursor;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  Future<List<Video>> build() async {
    return _fetchFirstPage();
  }

  Future<List<Video>> _fetchFirstPage() async {
    final service = ref.read(videoServiceProvider);
    final response = await service.getFeed(onlyFollowing: true);
    _nextCursor = response.nextCursor;
    _hasMore = _nextCursor != null;

    return response.videos;
  }

  Future<void> loadNextPage() async {
    if (!_hasMore || _isLoadingMore) return;

    _isLoadingMore = true;
    try {
      final service = ref.read(videoServiceProvider);
      final response = await service.getFeed(
        cursor: _nextCursor,
        onlyFollowing: true,
      );

      _nextCursor = response.nextCursor;
      _hasMore = _nextCursor != null;

      final currentVideos = state.value ?? [];
      state = AsyncData([...currentVideos, ...response.videos]);
    } catch (e) {
      print("Pagination error: $e");
    } finally {
      _isLoadingMore = false;
    }
  }

  void toggleLike(String videoId) {
    if (state.value == null) return;

    final currentVideos = state.value!;
    final index = currentVideos.indexWhere((v) => v.id == videoId);

    if (index != -1) {
      final originalVideo = currentVideos[index];
      final newIsLiked = !originalVideo.isLiked;
      final newLikesCount = originalVideo.likesCount + (newIsLiked ? 1 : -1);

      final updatedVideo = originalVideo.copyWith(
        isLiked: newIsLiked,
        likesCount: newLikesCount,
      );

      final List<Video> updatedList = List.from(currentVideos);
      updatedList[index] = updatedVideo;

      state = AsyncData(updatedList);
    }
  }
}
