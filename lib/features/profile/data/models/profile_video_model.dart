import '../../../auth/data/models/user_model.dart';
import '../../../feed/data/models/video_model.dart';

class ProfileVideo {
  final String id;
  final String thumbnail;
  final String description;
  final String videoPath;
  final bool allowComments;
  final String privacy;
  final int views;
  final String status;

  // Derived
  bool get isProcessing => status == 'processing';

  ProfileVideo({
    required this.id,
    required this.thumbnail,
    required this.description,
    required this.videoPath,
    required this.allowComments,
    required this.privacy,
    required this.views,
    required this.status,
  });

  factory ProfileVideo.fromJson(Map<String, dynamic> json) {
    return ProfileVideo(
      id: json['id'].toString(),
      thumbnail: json['thumbnail'] ?? '',
      description: json['description'] ?? '',
      videoPath: json['video_path'] ?? '',
      allowComments:
          json['allow_comments'] == 1 || json['allow_comments'] == true,
      privacy: json['privacy'] ?? 'public',
      views: json['views'] ?? 0,
      status: json['status'] ?? 'processed',
    );
  }

  Video toVideo(User user) {
    return Video(
      id: id,
      videoUrl: videoPath,
      thumbnailUrl: thumbnail,
      caption: description,
      likesCount: 0,
      commentsCount: 0,
      isLiked: false,
      user: user,
    );
  }
}
