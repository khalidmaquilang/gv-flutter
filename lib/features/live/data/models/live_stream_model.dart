import '../../../auth/data/models/user_model.dart';

class LiveStream {
  final String channelId;
  final User user;
  final String thumbnailUrl;
  final int viewersCount;
  final String title;

  LiveStream({
    required this.channelId,
    required this.user,
    required this.thumbnailUrl,
    required this.viewersCount,
    required this.title,
  });
}
