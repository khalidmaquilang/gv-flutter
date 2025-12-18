class ProfileVideo {
  final String thumbnail;
  final String privacy;
  final int views;

  ProfileVideo({
    required this.thumbnail,
    required this.privacy,
    required this.views,
  });

  factory ProfileVideo.fromJson(Map<String, dynamic> json) {
    return ProfileVideo(
      thumbnail: json['thumbnail'] ?? '',
      privacy: json['privacy'] ?? 'public',
      views: json['views'] ?? 0,
    );
  }
}
