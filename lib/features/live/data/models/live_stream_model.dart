import '../../../auth/data/models/user_model.dart';

class LiveStream {
  final String id;
  final String channelId; // This will be the stream_key
  final User user;
  final String title;
  final String? thumbnailUrl;
  final int viewersCount;
  final String? startedAt;
  final String? endedAt;

  LiveStream({
    required this.id,
    required this.channelId,
    required this.user,
    required this.title,
    this.thumbnailUrl,
    required this.viewersCount,
    this.startedAt,
    this.endedAt,
  });

  factory LiveStream.fromJson(Map<String, dynamic> json) {
    return LiveStream(
      id: json['id'] as String,
      channelId: json['content']['stream_key'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      title: json['title'] as String,
      thumbnailUrl:
          json['user']['avatar'] as String?, // Using user avatar as thumbnail
      viewersCount: json['views'] as int? ?? 0,
      startedAt: json['content']['started_at'] as String?,
      endedAt: json['content']['ended_at'] as String?,
    );
  }
}
