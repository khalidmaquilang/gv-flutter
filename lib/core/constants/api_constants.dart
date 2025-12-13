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
  static const String agoraAppId = "ba2f01fade2b425cbc0bf7406a9fa8d9";
  static const String agoraTempToken = ""; // Add your temporary token here
  static const String fixedTestChannelId =
      "test_channel"; // Fixed channel for testing
}
