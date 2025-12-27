class ApiConstants {
  static const String baseUrl =
      'https://30c3744d3432.ngrok-free.app/api/v1'; // Android Emulator localhost

  // Auth
  static const String login = '/login';
  static const String register = '/register';
  static const String user = '/user';
  static const String forgotPassword = '/forgot-password';

  // Profile
  static const String updateProfile = '/profile';
  static const String uploadProfileAvatar = '/profile/avatar';

  // Feed
  static const String feed = '/feeds';
  static const String videos = '/videos';
  static const String createPost = '/videos';
  static const String musics = '/musics';
  static const String myVideos = '/my-videos';

  // DeepAR
  static const String deepArAndroidLicenseKey =
      "2f95939383b07b667868a05a342b1c8f3dc6b9d923e08dfb7d8572074ef0536f7a940aa8886c5798";
  static const String deepArIosLicenseKey = "REPLACE_WITH_YOUR_IOS_KEY";

  // Agora
  static const String agoraAppId = "c0108ab6bba14678982d1aea8a4470b4";
  static const String agoraCustomerId =
      "1fbaf7050e6746ba92feaab6bc0998b5"; // Customer ID
  static const String agoraCustomerSecret =
      "8b84a7fa9c914c31ae0f32c125946751"; // Customer Secret
  static const String agoraTempToken = ""; // Add your temporary token here
  static const String fixedTestChannelId =
      "test_channel"; // Fixed channel for testing

  // Streaming
  static const String rtmpUrl = "rtmp://rtmp.maralabs.ph/live/test";
  static const String hlsPlayUrl = "https://hls.maralabs.ph/hls/test.m3u8";

  // Zego Cloud
  // TODO: Get these from ZEGOCLOUD Admin Console
  static const int zegoAppId = 525017043; // Replace with your AppID (int)
  static const String zegoAppSign =
      "a446793304316b50287aaf6be77e77758b3cda1be376b289af8c9db899c15f92"; // Replace with your AppSign (String)
}
