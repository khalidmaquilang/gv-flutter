import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:test_flutter/core/constants/api_constants.dart';

class MediaPushService {
  final Dio _dio = Dio();

  // Base URL for Agora REST API (Global/EU)
  // Using global endpoint for better reachability, or the one from the article if preferred.
  // Article used: https://api.agora.io/eu/v1/projects/{appid}/rtmp-converters
  static String get _baseUrl =>
      "https://api.agora.io/ap/v1/projects/${ApiConstants.agoraAppId}/rtmp-converters";

  Future<void> startMediaPush({
    required String channelId,
    required int uid,
    required String rtmpUrl,
  }) async {
    final url = "$_baseUrl";

    // NOTE: Standard Agora REST API requires Basic Auth with Customer ID/Secret.
    // User claims only App ID is needed.
    // We will attempt to use a custom header or no auth if that's what's implied,
    // but standardly this triggers 401.
    // We'll try to add standard headers if credentials exist, else minimal.

    final body = {
      "converter": {
        "name": "${channelId}_vertical",
        "transcodeOptions": {
          "rtcChannel": channelId,
          "audioOptions": {
            "codecProfile": "LC-AAC",
            "sampleRate": 48000,
            "bitrate": 48,
            "audioChannels": 1,
          },
          "videoOptions": {
            "canvas": {"width": 640, "height": 360, "color": 0x000000},
            "layout": [
              {
                "rtcStreamUid": uid,
                "region": {
                  "xPos": 0,
                  "yPos": 0,
                  "zIndex": 1,
                  "width": 640,
                  "height": 360,
                },
                "fillMode": "fit",
              },
            ],
            "codecProfile": "high",
            "frameRate": 15,
            "gop": 30,
            "bitrate": 400,
          },
        },
        "rtmpUrl": rtmpUrl,
        "idleTimeOut": 60,
      },
    };

    // Headers
    String basicAuth =
        'Basic ' +
        base64Encode(
          utf8.encode(
            '${ApiConstants.agoraCustomerId}:${ApiConstants.agoraCustomerSecret}',
          ),
        );
    Map<String, String> headers = {
      "Content-Type": "application/json",
      "Authorization": basicAuth,
    };

    try {
      debugPrint("MediaPushService: Starting push to $rtmpUrl via $_baseUrl");

      final response = await _dio.post(
        url,
        data: jsonEncode(body),
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        debugPrint("MediaPushService: Success! ${response.data}");
      } else {
        debugPrint("MediaPushService: Failed with ${response.statusCode}");
        throw Exception("API Error ${response.statusCode}: ${response.data}");
      }
    } on DioException catch (e) {
      debugPrint("MediaPushService: Dio Error $e");
      if (e.response != null) {
        debugPrint("MediaPushService: Response Data: ${e.response?.data}");
        throw Exception(
          "API Failed: ${e.response?.statusCode} ${e.response?.data}",
        );
      } else {
        throw Exception("Network Error: ${e.message}");
      }
    }
  }

  Future<void> stopMediaPush({required String channelId}) async {
    // Not strictly required for MVP test, and DELETE usually needs exact converter name/id
  }
}
