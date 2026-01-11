class ApiConstants {
  static const String baseUrl =
      'https://1c51a75c5653.ngrok-free.app/api/v1'; // Android Emulator localhost

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

  // Chat
  static const String chats = '/chats';
  static const String chatConversations = '/chats/conversations';
  static const String chatUnreadCount = '/chats/unread/count';
  static String chatMessages(String userId) => '/chats/$userId';
  static String markChatAsRead(String chatId) => '/chats/$chatId/read';

  // DeepAR
  static const String deepArAndroidLicenseKey =
      "bdc0c5c55c9b202efafe392f4a06f8be9585f082a8f370c2fecad4e027cd712e293c63730d249d8e";
  static const String deepArIosLicenseKey =
      "c8e3f93725530c06a59ee7efcc71f879b8af1932ddd04c308702f8c878adafeeaf4b63b4200e743e";

  // Streaming
  static const String rtmpUrl = "rtmp://rtmp.maralabs.ph/live/test";
  static const String hlsPlayUrl = "https://hls.maralabs.ph/hls/test.m3u8";

  // Zego Cloud
  // TODO: Get these from ZEGOCLOUD Admin Console
  static const int zegoAppId = 33314593; // Replace with your AppID (int)
  static const String zegoAppSign =
      "4ce1de23510d38c70b26458a350f38947851faddc39baa6506777b8f26b58cd3"; // Replace with your AppSign (String)

  // Broadcasting (Pusher/Reverb)
  // TODO: Update these with your broadcasting credentials
  static const String pusherAppKey =
      "6c991585b92b0c69b450"; // Or Reverb app key
  static const String pusherCluster = "ap1"; // For Pusher
  static const String pusherHost =
      "gv.stock-manager.online"; // For Reverb/self-hosted
  static const int pusherPort = 443;
  static const bool pusherUseTLS = true;
  static const String pusherScheme = "https";
}
