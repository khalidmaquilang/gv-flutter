class LiveMessage {
  final String username;
  final String message;
  final String? avatarUrl;

  LiveMessage({required this.username, required this.message, this.avatarUrl});
}

class LiveGift {
  final String username;
  final String giftName;
  final int value;

  LiveGift({
    required this.username,
    required this.giftName,
    required this.value,
  });
}

enum LiveReactionType { heart, fire, smile }

class LiveReaction {
  final LiveReactionType type;
  final String username;

  LiveReaction({required this.type, required this.username});
}
