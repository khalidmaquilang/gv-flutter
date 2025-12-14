class ApiConstants {
  static const String baseUrl =
      'https://6f3becc9b94f.ngrok-free.app/api'; // Android Emulator localhost

  // Auth
  static const String login = '/login';
  static const String register = '/register';
  static const String user = '/user';

  // Feed
  static const String videos = '/videos';

  // DeepAR
  static const String deepArAndroidLicenseKey =
      "2f95939383b07b667868a05a342b1c8f3dc6b9d923e08dfb7d8572074ef0536f7a940aa8886c5798";
  static const String deepArIosLicenseKey = "REPLACE_WITH_YOUR_IOS_KEY";

  // Agora
  static const String agoraAppId = "c65c4b6ba9ca46c5a5005cbcc1c072ae";
  static const String agoraCustomerId =
      "1fbaf7050e6746ba92feaab6bc0998b5"; // Customer ID
  static const String agoraCustomerSecret =
      "8b84a7fa9c914c31ae0f32c125946751"; // Customer Secret
  static const String agoraTempToken =
      "007eJxTYIjMOHyjZ0Pc5qAOzaS9UUcuzH4Sy21Z6H308kmm4ICvK3crMCSbmSabJJklJVomJ5qYJZsmmhoYmCYnJScbJhuYGyWmRsjYZzYEMjL4Zq9lZWSAQBCfh6EktbgkPjkjMS8vNYeBAQDW/yPP"; // Add your temporary token here
  static const String fixedTestChannelId =
      "test_channel"; // Fixed channel for testing

  // Streaming
  static const String rtmpUrl = "rtmp://rtmp.maralabs.ph/live/test";
  static const String hlsPlayUrl = "http://rtmp.maralabs.ph/hls/test.m3u8";
}
