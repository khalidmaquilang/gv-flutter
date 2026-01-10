import '../../../auth/data/models/user_model.dart';

class Conversation {
  final User user; // The other user in the conversation
  final String? lastMessage;
  final int unreadCount;
  final DateTime? lastMessageTime;

  Conversation({
    required this.user,
    this.lastMessage,
    this.unreadCount = 0,
    this.lastMessageTime,
  });

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
