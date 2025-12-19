import '../../../auth/data/models/user_model.dart';

class Video {
  final String id;
  final String videoUrl;
  final String thumbnailUrl;
  final String caption;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final User user;

  Video({
    required this.id,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.caption,
    required this.likesCount,
    required this.commentsCount,
    this.isLiked = false,
    required this.user,
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: json['id'].toString(),
      videoUrl: json['video_url'] ?? '',
      thumbnailUrl: json['thumbnail_url'] ?? '',
      caption: json['description'] ?? '',
      likesCount: json['likes_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
      user: User.fromJson(json['user']),
    );
  }
}
