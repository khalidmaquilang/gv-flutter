import '../../../auth/data/models/user_model.dart';
import '../../../feed/data/models/video_model.dart';
import '../../../camera/data/models/sound_model.dart';

class ProfileVideo {
  final String id;
  final String thumbnail;
  final String description;
  final String videoPath;
  final bool allowComments;
  final String privacy;
  final int views;
  final String status;
  final Sound? sound;

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
    this.sound,
  });

  factory ProfileVideo.fromJson(Map<String, dynamic> json) {
    final feed = json['feed'] ?? {};
    return ProfileVideo(
      id: feed['id']?.toString() ?? '',
      thumbnail: json['thumbnail'] ?? '', // Root level
      description: feed['title'] ?? '', // Maps to feed title
      videoPath: json['video_path'] ?? '', // Root level
      allowComments:
          feed['allow_comments'] == 1 || feed['allow_comments'] == true,
      privacy: feed['privacy'] ?? 'public',
      views: feed['views'] ?? 0,
      status: feed['status'] ?? 'processed',
      sound: json['music'] != null ? Sound.fromJson(json['music']) : null,
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
      sound: sound,
    );
  }
}
