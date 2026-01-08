class ApiConstants {
  static const String baseUrl =
      'https://bbdb3665fafa.ngrok-free.app/api/v1'; // Android Emulator localhost

  // Auth
  static const String login = '/login';
  static const String register = '/register';
  static const String user = '/user';
  static const String forgotPassword = '/forgot-password';

  // Profile
  static const String updateProfile = '/profile';
  static const String uploadProfileAvatar = '/profile/avatar';

  // Follow
  static String followUser(String userId) => '/users/$userId/follow';
  static String unfollowUser(String userId) => '/users/$userId/follow';
  static String userVideos(String userId) => '/users/$userId/videos';

  // Feed
  static const String feed = '/feeds';
  static const String feedFollowing = '/feeds/following';
  static const String videos = '/videos';
  static const String createPost = '/videos';
  static const String musics = '/musics';
  static const String myVideos = '/my-videos';

  // DeepAR
  static const String deepArAndroidLicenseKey =
      "2f95939383b07b667868a05a342b1c8f3dc6b9d923e08dfb7d8572074ef0536f7a940aa8886c5798";
  static const String deepArIosLicenseKey =
      "b3feba950e64e1989d70661df9c87af9e549b02bbf8ba4fdf051e8f9abe89528b7776cde50e35e6a";

  // Streaming
  static const String rtmpUrl = "rtmp://rtmp.maralabs.ph/live/test";
  static const String hlsPlayUrl = "https://hls.maralabs.ph/hls/test.m3u8";

  // Zego Cloud
  // TODO: Get these from ZEGOCLOUD Admin Console
  static const int zegoAppId = 33314593; // Replace with your AppID (int)
  static const String zegoAppSign =
      "4ce1de23510d38c70b26458a350f38947851faddc39baa6506777b8f26b58cd3"; // Replace with your AppSign (String)
}
