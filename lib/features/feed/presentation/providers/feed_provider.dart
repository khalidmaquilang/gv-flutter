import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/video_model.dart';
import '../../data/services/video_service.dart';
import '../../../auth/data/models/user_model.dart';

import '../../../../core/providers/api_provider.dart';

final videoServiceProvider = Provider((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return VideoService(apiClient: apiClient);
});

final feedProvider = FutureProvider<List<Video>>((ref) async {
  final service = ref.read(videoServiceProvider);
  final videos = await service.getFeed();

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

  return [dummyVideo, ...videos];
});
