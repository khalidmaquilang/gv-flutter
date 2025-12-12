import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/data/models/user_model.dart';
import '../../data/services/chat_service.dart';
import 'chat_detail_screen.dart';

final chatServiceProvider = Provider((ref) => ChatService());

final conversationsProvider = FutureProvider<List<User>>((ref) async {
  return ref.read(chatServiceProvider).getConversations();
});

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("Inbox")),
      body: conversationsAsync.when(
        data: (users) => ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(user.avatar ?? ""),
              ),
              title: Text(
                user.name,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                "Sent a message",
                style: TextStyle(color: Colors.grey),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ChatDetailScreen(user: user),
                  ),
                );
              },
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text("Error: $err")),
      ),
    );
  }
}
