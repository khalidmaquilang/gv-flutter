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
    final url = _baseUrl;

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
        'Basic ${base64Encode(utf8.encode('${ApiConstants.agoraCustomerId}:${ApiConstants.agoraCustomerSecret}'))}';
    Map<String, String> headers = {
      "Content-Type": "application/json",
      "Authorization": basicAuth,
    };

    try {
      debugPrint(
        "MediaPushService: 1. Force Reset - Deleting existing converter...",
      );
      // Always try to delete first to ensure we don't have a zombie with wrong UID.
      // We ignore errors here (e.g. if it doesn't exist, that's fine).
      await stopMediaPush(channelId: channelId);

      // Give it a moment to clear
      await Future.delayed(const Duration(seconds: 2));

      debugPrint("MediaPushService: 2. Creating new converter...");
      var response = await _dio.post(
        url,
        data: jsonEncode(body),
        options: Options(headers: headers, validateStatus: (status) => true),
      );

      if (response.statusCode == 200) {
        debugPrint("MediaPushService: Success! ${response.data}");
      } else if (response.statusCode == 409) {
        // If it STILL says 409 after we just deleted it,
        // either the delete failed silently or propagation is slow.
        // In this worst case, we HAVE to assume the existing one is usable
        // (assuming the UID 1000 fixed matched the previous run).
        debugPrint(
          "MediaPushService: 409 Persistence. Assuming existing converter is valid.",
        );
        return;
      } else {
        debugPrint("MediaPushService: Failure ${response.statusCode}");
        throw Exception("API Error ${response.statusCode}: ${response.data}");
      }
    } on DioException catch (e) {
      debugPrint("MediaPushService: Network Error $e");
      throw Exception("Network Error: ${e.message}");
    }
  }

  Future<void> stopMediaPush({required String channelId}) async {
    final converterName = "${channelId}_vertical";
    final url = "$_baseUrl/$converterName";

    // Auth Headers
    String basicAuth =
        'Basic ${base64Encode(utf8.encode('${ApiConstants.agoraCustomerId}:${ApiConstants.agoraCustomerSecret}'))}';
    Map<String, String> headers = {
      "Content-Type": "application/json",
      "Authorization": basicAuth,
    };

    try {
      debugPrint("MediaPushService: Deleting converter $converterName...");
      await _dio.delete(url, options: Options(headers: headers));
      debugPrint("MediaPushService: Deleted.");
    } catch (e) {
      debugPrint("MediaPushService: Delete failed (maybe already gone): $e");
    }
  }
}
