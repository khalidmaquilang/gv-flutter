import '../../../camera/data/models/sound_model.dart';
import '../../../auth/data/models/user_model.dart';

class Video {
  final String id;
  final String videoUrl;
  final String thumbnailUrl;
  final String caption;
  final int likesCount;
  final bool isLiked;
  final User user;
  final Sound? sound;
  final String privacy;
  final bool allowComments;
  final String status;
  final int views;
  final String formattedReactionsCount;
  final String formattedViews;
  final String? streamKey; // For live streams
  final String? startedAt; // For live streams
  final String? endedAt; // For live streams

  // Helper to check if this is a live stream
  bool get isLiveStream => streamKey != null;
  bool get isLiveBroadcasting =>
      streamKey != null && startedAt != null && endedAt == null;

  Video({
    required this.id,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.caption,
    required this.likesCount,
    this.isLiked = false,
    required this.user,
    this.sound,
    this.privacy = 'public',
    this.allowComments = true,
    this.status = 'processed',
    this.views = 0,
    this.formattedReactionsCount = '0',
    this.formattedViews = '0',
    this.streamKey,
    this.startedAt,
    this.endedAt,
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    final content = json['content'] as Map<String, dynamic>? ?? {};

    return Video(
      id: json['id']?.toString() ?? '',
      videoUrl: content['video_path'] ?? json['video_url'] ?? '',
      thumbnailUrl: content['thumbnail'] ?? json['thumbnail_url'] ?? '',
      caption: json['title'] ?? json['description'] ?? '',
      likesCount: json['reactions_count'] ?? json['likes_count'] ?? 0,
      isLiked: json['is_reacted_by_user'] ?? json['is_liked'] ?? false,
      user: User.fromJson(json['user']),
      sound: json['music'] != null ? Sound.fromJson(json['music']) : null,
      privacy: json['privacy'] ?? 'public',
      allowComments: json['allow_comments'] ?? true,
      status: json['status'] ?? 'processed',
      views: json['views'] ?? 0,
      formattedReactionsCount:
          json['formatted_reactions_count']?.toString() ?? '0',
      formattedViews: json['formatted_views']?.toString() ?? '0',
      streamKey: content['stream_key'], // Extract stream_key for live streams
      startedAt: content['started_at'],
      endedAt: content['ended_at'],
    );
  }

  Video copyWith({
    String? id,
    String? videoUrl,
    String? thumbnailUrl,
    String? caption,
    int? likesCount,
    bool? isLiked,
    User? user,
    Sound? sound,
    String? privacy,
    bool? allowComments,
    String? status,
    int? views,
    String? formattedReactionsCount,
    String? formattedViews,
    String? streamKey,
    String? startedAt,
    String? endedAt,
  }) {
    return Video(
      id: id ?? this.id,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      caption: caption ?? this.caption,
      likesCount: likesCount ?? this.likesCount,
      isLiked: isLiked ?? this.isLiked,
      user: user ?? this.user,
      sound: sound ?? this.sound,
      privacy: privacy ?? this.privacy,
      allowComments: allowComments ?? this.allowComments,
      status: status ?? this.status,
      views: views ?? this.views,
      formattedReactionsCount:
          formattedReactionsCount ?? this.formattedReactionsCount,
      formattedViews: formattedViews ?? this.formattedViews,
      streamKey: streamKey ?? this.streamKey,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }
}
