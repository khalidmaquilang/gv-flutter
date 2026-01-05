class GiftItem {
  final String id;
  final String name;
  final String emoji;
  final int price;
  final String? animationPath;

  const GiftItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.price,
    this.animationPath,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'price': price,
  };

  factory GiftItem.fromJson(Map<String, dynamic> json) {
    return GiftItem(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      price: json['price'] as int,
    );
  }
}

class GiftMessage {
  final String senderUserId;
  final String senderUserName;
  final GiftItem gift;
  final int count;
  final int timestamp;

  const GiftMessage({
    required this.senderUserId,
    required this.senderUserName,
    required this.gift,
    required this.count,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'sender_user_id': senderUserId,
    'sender_user_name': senderUserName,
    'gift_id': gift.id,
    'gift_name': gift.name,
    'gift_emoji': gift.emoji,
    'count': count,
    'timestamp': timestamp,
  };

  factory GiftMessage.fromJson(Map<String, dynamic> json) {
    return GiftMessage(
      senderUserId: json['sender_user_id'] as String,
      senderUserName: json['sender_user_name'] as String,
      gift: GiftItem(
        id: json['gift_id'] as String,
        name: json['gift_name'] as String,
        emoji: json['gift_emoji'] as String,
        price: 0, // Price not needed when receiving
      ),
      count: json['count'] as int,
      timestamp: json['timestamp'] as int,
    );
  }
}
