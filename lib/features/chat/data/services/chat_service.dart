import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../auth/data/models/user_model.dart';
import '../models/chat_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ChatService {
  final ApiClient _apiClient;
  final _storage = const FlutterSecureStorage();

  ChatService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// GET /chats/{userId} - Get chat messages between authenticated user and another user
  Future<ChatResponse> getChats(String userId, {String? cursor}) async {
    try {
      // Set auth token
      final token = await _storage.read(key: 'auth_token');
      if (token != null) {
        _apiClient.setToken(token);
      }

      final endpoint = cursor != null
          ? "${ApiConstants.chatMessages(userId)}?cursor=$cursor"
          : ApiConstants.chatMessages(userId);

      final response = await _apiClient.get(endpoint);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] as List;
        final chats = data.map((e) => Chat.fromJson(e)).toList();
        final nextCursor = response.data['next_cursor'] as String?;

        return ChatResponse(chats: chats, nextCursor: nextCursor);
      }

      return ChatResponse(chats: [], nextCursor: null);
    } catch (e) {
      print("Get Chats Error: $e");
      return ChatResponse(chats: [], nextCursor: null);
    }
  }

  /// POST /chats - Send a new chat message
  Future<String?> sendMessage(String receiverId, String message) async {
    try {
      // Set auth token
      final token = await _storage.read(key: 'auth_token');
      if (token != null) {
        _apiClient.setToken(token);
      }

      final response = await _apiClient.post(
        ApiConstants.chats,
        data: {"receiver_id": receiverId, "message": message},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['id']?.toString();
      }
      return null;
    } catch (e) {
      print("Send Message Error: $e");
      return null;
    }
  }

  /// POST /chats/{chatId}/read - Mark a chat message as read
  Future<bool> markAsRead(String chatId) async {
    try {
      // Set auth token
      final token = await _storage.read(key: 'auth_token');
      if (token != null) {
        _apiClient.setToken(token);
      }

      final response = await _apiClient.post(
        ApiConstants.markChatAsRead(chatId),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("Mark As Read Error: $e");
      return false;
    }
  }

  /// GET /chats/unread/count - Get total unread message count
  Future<int> getUnreadCount() async {
    try {
      // Set auth token
      final token = await _storage.read(key: 'auth_token');
      if (token != null) {
        _apiClient.setToken(token);
      }

      final response = await _apiClient.get(ApiConstants.chatUnreadCount);

      if (response.statusCode == 200 && response.data != null) {
        return response.data['unread_count'] ?? 0;
      }
      return 0;
    } catch (e) {
      print("Get Unread Count Error: $e");
      return 0;
    }
  }

  /// Mock method to get conversations (will be replaced with real API later)
  /// This aggregates chat data to show on the chat list screen
  Future<List<User>> getConversations() async {
    // TODO: Create a backend endpoint to get list of users with recent conversations
    // For now, returning empty to be compatible with existing code
    return [];
  }
}

class ChatResponse {
  final List<Chat> chats;
  final String? nextCursor;

  ChatResponse({required this.chats, this.nextCursor});
}
