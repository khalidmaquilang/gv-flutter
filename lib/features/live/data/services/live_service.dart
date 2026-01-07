import 'dart:async';
import 'dart:convert';
import 'package:agora_rtm/agora_rtm.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/live_interaction_model.dart';
import 'package:test_flutter/core/constants/api_constants.dart';
import 'package:test_flutter/core/network/api_client.dart';
import '../models/live_stream_model.dart';
import '../../../auth/data/models/user_model.dart';
import 'dart:math';

class LiveService {
  // Streams for UI
  final _messageController = StreamController<LiveMessage>.broadcast();
  final _reactionController = StreamController<LiveReaction>.broadcast();
  final _giftController = StreamController<LiveGift>.broadcast();

  Stream<LiveMessage> get messageStream => _messageController.stream;
  Stream<LiveReaction> get reactionStream => _reactionController.stream;
  Stream<LiveGift> get giftStream => _giftController.stream;

  // Agora RTM 2.x
  RtmClient? _rtmClient;
  StreamChannel? _streamChannel;
  String? _currentUserId;
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

  Future<void> initialize({
    required String uid,
    required String channelId,
  }) async {
    if (_rtmClient != null) return;

    _currentUserId = uid;
    _currentChannelId = channelId;

    try {
      // 1. Create Client (RTM 2.x using global RTM function)
      // Note: RTM is a top-level function exported by agora_rtm
      final (status, client) = await RTM(ApiConstants.agoraAppId, uid);

      if (status.error == true) {
        debugPrint("RTM Create Error: ${status.errorCode}");
        return;
      }
      _rtmClient = client;

      // 2. Add Listener (Named callbacks)
      _rtmClient!.addListener(
        message: (MessageEvent event) {
          _handleMessageReceived(event);
        },
        linkState: (LinkStateEvent event) {
          debugPrint("RTM Link State: ${event.currentState}");
        },
      );

      // 3. Login
      final (loginStatus, _) = await _rtmClient!.login(
        ApiConstants.agoraTempToken,
      );
      if (loginStatus.error == true) {
        debugPrint("RTM Login Failed: ${loginStatus.errorCode}");
        return;
      }
      debugPrint("RTM Info: Logged in as $uid");

      // 4. Create & Join Stream Channel
      // Note: StreamChannel is for data/signaling synchronization with RTC.
      // If simple chat is needed, MessageChannel could be used, but StreamChannel is robust.
      // We will use "chat" as the topic.
      final (chanStatus, channel) = await _rtmClient!.createStreamChannel(
        channelId,
      );
      if (chanStatus.error == true || channel == null) {
        debugPrint("RTM Create Stream Channel Failed: ${chanStatus.errorCode}");
        return;
      }
      _streamChannel = channel;

      final (joinStatus, _) = await _streamChannel!.join(
        token: ApiConstants.agoraTempToken,
        withMetadata: false,
        withPresence: true,
        withLock: false,
      );

      if (joinStatus.error == true) {
        debugPrint("RTM Join Stream Channel Failed: ${joinStatus.errorCode}");
      } else {
        debugPrint("RTM Info: Joined stream channel $channelId");
        // Join the topic "chat" to send/receive messages?
        // StreamChannel requires joining a topic to publish/subscribe?
        // From docs: joinTopic is needed.
        await _streamChannel!.joinTopic("chat");
        await _streamChannel!.subscribeTopic("chat");
      }
    } catch (e) {
      debugPrint("RTM Init Catch: $e");
    }
  }

  void _handleMessageReceived(MessageEvent event) {
    try {
      final msgString = event.message != null
          ? utf8.decode(event.message!)
          : "";

      if (msgString.isEmpty) return;

      final Map<String, dynamic> data = jsonDecode(msgString);
      final type = data['type'];
      final senderName = data['username'] ?? "User";

      switch (type) {
        case 'chat':
          _messageController.add(
            LiveMessage(username: senderName, message: data['message']),
          );
          break;
        case 'reaction':
          _reactionController.add(
            LiveReaction(type: LiveReactionType.heart, username: senderName),
          );
          break;
        case 'gift':
          _giftController.add(
            LiveGift(
              username: senderName,
              giftName: data['giftName'] ?? 'Gift',
              value: data['value'] ?? 0,
            ),
          );
          break;
      }
    } catch (e) {
      debugPrint("RTM Parse Error: $e");
    }
  }

  Future<void> dispose() async {
    debugPrint("RTM: Disposing service for channel $_currentChannelId");
    _messageController.close();
    _reactionController.close();
    _giftController.close();

    try {
      if (_streamChannel != null) {
        await _streamChannel!.leaveTopic("chat");
        await _streamChannel!.leave();
        _streamChannel = null;
      }
      if (_rtmClient != null) {
        await _rtmClient!.logout();
        _rtmClient = null;
      }
    } catch (e) {
      debugPrint("RTM Dispose Error: $e");
    }
  }

  // User Actions

  Future<void> sendComment(String text) async {
    // Optimistic UI: Echo locally immediately
    _messageController.add(LiveMessage(username: 'Me', message: text));

    if (_streamChannel == null) return;

    final payload = jsonEncode({
      'type': 'chat',
      'username': _currentUserId ?? 'Me',
      'message': text,
    });

    await _publish(payload);
  }

  Future<void> sendReaction() async {
    // Optimistic UI
    _reactionController.add(
      LiveReaction(type: LiveReactionType.heart, username: 'Me'),
    );

    if (_streamChannel == null) return;

    final payload = jsonEncode({
      'type': 'reaction',
      'username': _currentUserId ?? 'Me',
    });

    await _publish(payload);
  }

  Future<void> sendGift(String name, int value) async {
    // Optimistic UI
    _giftController.add(LiveGift(username: 'Me', giftName: name, value: value));

    if (_streamChannel == null) return;

    final payload = jsonEncode({
      'type': 'gift',
      'username': _currentUserId ?? 'Me',
      'giftName': name,
      'value': value,
    });

    await _publish(payload);
  }

  Future<void> _publish(String msg) async {
    try {
      // publishTextMessage expects (topic, message)
      await _streamChannel!.publishTextMessage("chat", msg);
    } catch (e) {
      debugPrint("Publish Error: $e");
    }
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
    await Future.delayed(const Duration(milliseconds: 500));
    return List.generate(10, (index) {
      // FORCE SYNC: First stream matches the Host's "Go Live" ID
      if (index == 0) {
        return LiveStream(
          channelId: ApiConstants.fixedTestChannelId,
          user: User(
            id: "host_user",
            name: "Test Host",
            email: "host@test.com",
            avatar: "https://dummyimage.com/50",
          ),
          thumbnailUrl: "https://dummyimage.com/300x400",
          viewersCount: 0,
          title: "LIVE NOW (Test Channel)",
        );
      }
      return LiveStream(
        channelId: "channel_$index",
        user: User(
          id: index.toString(),
          name: "Live User $index",
          email: "live$index@test.com",
          avatar: "https://dummyimage.com/50",
        ),
        thumbnailUrl: "https://dummyimage.com/300x400",
        viewersCount: Random().nextInt(5000) + 100,
        title: "Live Stream #$index - Join now!",
      );
    });
  }
}
