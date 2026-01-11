import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';
import '../network/api_client.dart';

class BroadcastingService {
  static final BroadcastingService _instance = BroadcastingService._internal();
  factory BroadcastingService() => _instance;
  BroadcastingService._internal();

  PusherChannelsFlutter? _pusher;
  bool _isInitialized = false;
  String? _currentUserId;

  PusherChannelsFlutter? get pusher => _pusher;
  bool get isInitialized => _isInitialized;

  /// Initialize Pusher connection
  Future<void> initialize(String userId, String authToken) async {
    if (_isInitialized && _currentUserId == userId) {
      print('Broadcasting already initialized for user $userId');
      return;
    }

    _currentUserId = userId;

    try {
      _pusher = PusherChannelsFlutter.getInstance();

      await _pusher!.init(
        apiKey: ApiConstants.pusherAppKey,
        cluster: ApiConstants.pusherCluster,
        onConnectionStateChange: onConnectionStateChange,
        onError: onError,
        onSubscriptionSucceeded: onSubscriptionSucceeded,
        onEvent: onEvent,
        onSubscriptionError: onSubscriptionError,
        onDecryptionFailure: onDecryptionFailure,
        onMemberAdded: onMemberAdded,
        onMemberRemoved: onMemberRemoved,
        // For self-hosted (Reverb)
        // Uncomment if using Reverb/self-hosted instead of Pusher
        // hostOptions: PusherHostOptions(
        //   host: ApiConstants.pusherHost,
        //   port: ApiConstants.pusherPort,
        //   encrypted: ApiConstants.pusherUseTLS,
        // ),
        onAuthorizer: onAuthorizer,
      );

      await _pusher!.connect();
      _isInitialized = true;
      print('Broadcasting initialized successfully');
    } catch (e) {
      print('Broadcasting initialization error: $e');
      _isInitialized = false;
    }
  }

  /// Subscribe to a private channel
  Future<void> subscribeToPrivateChannel(
    String channelName,
    Function(PusherEvent) onEventCallback,
  ) async {
    if (!_isInitialized || _pusher == null) {
      print('Cannot subscribe: Broadcasting not initialized');
      return;
    }

    try {
      await _pusher!.subscribe(
        channelName: channelName,
        onEvent: onEventCallback,
      );
      print('Subscribed to channel: $channelName');
    } catch (e) {
      print('Error subscribing to channel $channelName: $e');
    }
  }

  /// Unsubscribe from a channel
  Future<void> unsubscribe(String channelName) async {
    if (_pusher == null) return;

    try {
      await _pusher!.unsubscribe(channelName: channelName);
      print('Unsubscribed from channel: $channelName');
    } catch (e) {
      print('Error unsubscribing from channel $channelName: $e');
    }
  }

  /// Disconnect from Pusher
  Future<void> disconnect() async {
    if (_pusher == null) return;

    try {
      await _pusher!.disconnect();
      _isInitialized = false;
      _currentUserId = null;
      print('Broadcasting disconnected');
    } catch (e) {
      print('Error disconnecting from broadcasting: $e');
    }
  }

  // Callback handlers
  void onConnectionStateChange(dynamic currentState, dynamic previousState) {
    print('Connection state changed: $previousState -> $currentState');
  }

  void onError(String message, int? code, dynamic e) {
    print('Broadcasting error: $message (code: $code)');
  }

  void onEvent(PusherEvent event) {
    print('Broadcasting event: ${event.eventName} on ${event.channelName}');
  }

  void onSubscriptionSucceeded(String channelName, dynamic data) {
    print('Subscription succeeded: $channelName');
  }

  void onSubscriptionError(String message, dynamic e) {
    print('Subscription error: $message');
  }

  void onDecryptionFailure(String event, String reason) {
    print('Decryption failure: $event - $reason');
  }

  void onMemberAdded(String channelName, PusherMember member) {
    print('Member added to $channelName: ${member.userId}');
  }

  void onMemberRemoved(String channelName, PusherMember member) {
    print('Member removed from $channelName: ${member.userId}');
  }

  /// Authorization handler for private channels
  dynamic onAuthorizer(
    String channelName,
    String socketId,
    dynamic options,
  ) async {
    try {
      // Get the auth token from secure storage
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: 'auth_token');

      if (token == null) {
        print('No auth token found for broadcasting authorization');
        return null;
      }

      // Make request to Laravel broadcasting/auth endpoint
      final apiClient = ApiClient();
      final response = await apiClient.post(
        '/broadcasting/auth',
        data: {'socket_id': socketId, 'channel_name': channelName},
      );

      if (response.statusCode == 200) {
        return response.data;
      }

      return null;
    } catch (e) {
      print('Authorization error: $e');
      return null;
    }
  }
}
