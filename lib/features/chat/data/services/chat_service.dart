import 'package:dio/dio.dart';
import '../../../auth/data/models/user_model.dart';

class ChatService {
  // final Dio _dio;

  ChatService({Dio? dio}); // : _dio = dio ?? Dio();

  Future<List<User>> getConversations() async {
    // Mock
    await Future.delayed(const Duration(milliseconds: 500));
    return List.generate(
      5,
      (index) => User(
        id: index + 10,
        name: "Chat User $index",
        email: "chat$index@test.com",
        avatar: "https://via.placeholder.com/50",
        bio: "Hi",
      ),
    );
  }

  Future<List<Map<String, dynamic>>> getMessages(int userId) async {
    // Mock
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      {'senderId': 1, 'text': 'Hello!', 'time': '10:00 AM'},
      {'senderId': userId, 'text': 'Hi there!', 'time': '10:01 AM'},
      {'senderId': 1, 'text': 'How are you?', 'time': '10:02 AM'},
    ];
  }

  Future<void> sendMessage(int userId, String text) async {
    // Mock Send
  }
}
