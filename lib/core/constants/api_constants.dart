class ApiConstants {
  static const String baseUrl =
      'https://eb5c238860c7.ngrok-free.app/api/v1'; // Android Emulator localhost

  // Auth
  static const String login = '/login';
  static const String register = '/register';
  static const String user = '/user';
  static const String forgotPassword = '/forgot-password';

  // Feed
  static const String videos = '/videos';
  static const String createPost = '/videos';
  static const String musics = '/musics';
  static const String myVideos = '/my-videos';

  // Banuba
  static const String banubaToken =
      "Qk5CIGRq/LNYIrgbFApFapYXsEoZ0OSTPh7ixIq45vlAl3qbkPrNZoE/m7ORS+Ns3va8xQSzo5IUHszToOhA00fzud069dWll8nzH6AJe7C2fYO1L/8MvT6i33nM8xIR7y+foBLG8wHtgAnTidsp6TKccuFVMKFm7T+pJ0U0I6oJu9gffw+9ulYza8McLBqeBFBcSIcf2Gm5X4Alf5SMbT5wnA7FswdY5lpp75RN6WV/h6zH4ayBPkU/LwMUwH0Tfd0cVVsmKlRzsmEjRzD1J2O6lHALqFZYOvibFxayhdHUqz2pAkrn4knCgMhL3GcEAmAB2SHcUM3E8y1+th+63hgWzCP3FxMOVm1fPgrGEsyf/5IrqkLZAuPX3+0G976iEFCLf1f4bb1xZjQhJtDQRCA1I/TaiondUZGikDWNoHC/LRwZwqJi0rqMVGMIi5aUedfcx5NGPY2HWQ5XTOK0bxr2Hu6fC947vs5LBOzuaFh8MDuu7orGar3eFl5mjlzo6ODlTDk0j4N7AJX/vI+bZ+Ug+4yFdzifgyGHKEl46+tHxQy+Ya5hwGXHnFsyhFJtoI5pxSFPLudXJoQPrS/WIVEN9rsJbasjkc+73XKANr1xKyI0iTeNQVE19KbR4Z0WkzGL6MizYvkvc4zTPLHpNuMidw==";

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
  static const String hlsPlayUrl = "http://rtmp.maralabs.ph/hls/test.m3u8";
}
