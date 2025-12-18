class ProfileVideo {
  final String id;
  final String thumbnail;
  final String privacy;
  final int views;

  ProfileVideo({
    required this.id,
    required this.thumbnail,
    required this.privacy,
    required this.views,
  });

  factory ProfileVideo.fromJson(Map<String, dynamic> json) {
    return ProfileVideo(
      id: json['id']?.toString() ?? '',
      thumbnail: json['thumbnail'] ?? '',
      privacy: json['privacy'] ?? 'public',
      views: json['views'] ?? 0,
    );
  }
}
