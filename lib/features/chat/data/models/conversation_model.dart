import '../../../auth/data/models/user_model.dart';

class Conversation {
  final String id;
  final List<User> participants;
  final String? lastMessage;
  final int unreadCount;
  final DateTime? lastMessageTime;

  Conversation({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.unreadCount = 0,
    this.lastMessageTime,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    // Parse participants array
    final participantsList =
        (json['participants'] as List?)
            ?.map((p) => User.fromJson(p as Map<String, dynamic>))
            .toList() ??
        [];

    // Parse last_message object
    final lastMessageData = json['last_message'] as Map<String, dynamic>?;
    final messageText = lastMessageData?['message'] as String?;
    final createdAt = lastMessageData?['created_at'] as String?;

    return Conversation(
      id: json['id'] as String,
      participants: participantsList,
      lastMessage: messageText,
      unreadCount: json['unread_count'] as int? ?? 0,
      lastMessageTime: createdAt != null ? DateTime.parse(createdAt) : null,
    );
  }

  // Get the other user (for direct conversations)
  User? get user => participants.isNotEmpty ? participants.first : null;

  // Helper method to get formatted time
  String get formattedTime {
    if (lastMessageTime == null) return '';

    final now = DateTime.now();
    final difference = now.difference(lastMessageTime!);

    if (difference.inDays == 0) {
      final hours = lastMessageTime!.hour;
      final minutes = lastMessageTime!.minute.toString().padLeft(2, '0');
      final period = hours >= 12 ? 'PM' : 'AM';
      final displayHour = hours > 12 ? hours - 12 : (hours == 0 ? 12 : hours);
      return '$displayHour:$minutes $period';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${lastMessageTime!.month}/${lastMessageTime!.day}/${lastMessageTime!.year}';
    }
  }
}
