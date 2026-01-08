import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/live_interaction_model.dart';
import 'package:test_flutter/core/network/api_client.dart';
import '../models/live_stream_model.dart';

/// LiveService handles live stream interactions.
/// Note: Real-time messaging (RTM) functionality has been removed.
/// This service now only provides API-based live stream management.
class LiveService {
  // Streams for UI
  final _messageController = StreamController<LiveMessage>.broadcast();
  final _reactionController = StreamController<LiveReaction>.broadcast();
  final _giftController = StreamController<LiveGift>.broadcast();

  Stream<LiveMessage> get messageStream => _messageController.stream;
  Stream<LiveReaction> get reactionStream => _reactionController.stream;
  Stream<LiveGift> get giftStream => _giftController.stream;

  String? _currentChannelId;

  // API Client
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  LiveService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  // Helper to set auth token on ApiClient
  Future<bool> _setAuthToken() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) {
      debugPrint('No auth token found');
      return false;
    }
    _apiClient.setToken(token);
    return true;
  }

  /// Initialize the live service for a channel.
  /// Note: RTM functionality has been removed. This is now a no-op
  /// that just stores the channel ID for local use.
  Future<void> initialize({
    required String uid,
    required String channelId,
  }) async {
    _currentChannelId = channelId;
    debugPrint(
      "LiveService: Initialized for user $uid in channel $channelId (RTM disabled)",
    );
  }

  Future<void> dispose() async {
    debugPrint("LiveService: Disposing service for channel $_currentChannelId");
    _messageController.close();
    _reactionController.close();
    _giftController.close();
  }

  // User Actions - These now only update local UI (optimistic updates)
  // Without RTM, messages won't be sent to other users

  Future<void> sendComment(String text) async {
    // Optimistic UI: Echo locally immediately
    _messageController.add(LiveMessage(username: 'Me', message: text));
    debugPrint("LiveService: Comment sent locally (RTM disabled)");
  }

  Future<void> sendReaction() async {
    // Optimistic UI
    _reactionController.add(
      LiveReaction(type: LiveReactionType.heart, username: 'Me'),
    );
    debugPrint("LiveService: Reaction sent locally (RTM disabled)");
  }

  Future<void> sendGift(String name, int value) async {
    // Optimistic UI
    _giftController.add(LiveGift(username: 'Me', giftName: name, value: value));
    debugPrint("LiveService: Gift sent locally (RTM disabled)");
  }

  // API Methods for Live Stream Management
  Future<Map<String, dynamic>?> createLive(String title) async {
    try {
      if (!await _setAuthToken()) return null;

      final response = await _apiClient.post('/lives', data: {'title': title});

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        debugPrint('Live created successfully: ${data['id']}');
        return data;
      } else {
        debugPrint('Failed to create live: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error creating live: $e');
      return null;
    }
  }

  Future<bool> startLive(String liveId) async {
    try {
      if (!await _setAuthToken()) return false;

      final response = await _apiClient.post('/lives/$liveId/start');

      if (response.statusCode == 200) {
        debugPrint('Live started successfully: $liveId');
        return true;
      } else {
        debugPrint('Failed to start live: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Error starting live: $e');
      return false;
    }
  }

  Future<bool> endLive(String liveId) async {
    try {
      if (!await _setAuthToken()) return false;

      final response = await _apiClient.post('/lives/$liveId/end');

      if (response.statusCode == 200) {
        debugPrint('Live ended successfully: $liveId');
        return true;
      } else {
        debugPrint('Failed to end live: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Error ending live: $e');
      return false;
    }
  }

  Future<List<LiveStream>> getActiveStreams() async {
    try {
      if (!await _setAuthToken()) return [];

      final response = await _apiClient.get('/feeds/live');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final List<dynamic> feedsData = data['data'] as List<dynamic>;

        return feedsData
            .map((json) => LiveStream.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        debugPrint('Failed to fetch live feeds: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching live feeds: $e');
      return [];
    }
  }
}
