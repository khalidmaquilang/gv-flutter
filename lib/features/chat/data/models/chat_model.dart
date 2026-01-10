import '../../../auth/data/models/user_model.dart';

class Chat {
  final String id;
  final User sender;
  final User receiver;
  final String message;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;
  final String? formattedCreatedAt;

  Chat({
    required this.id,
    required this.sender,
    required this.receiver,
    required this.message,
    this.isRead = false,
    this.readAt,
    required this.createdAt,
    this.formattedCreatedAt,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id']?.toString() ?? '',
      sender: User.fromJson(json['sender']),
      receiver: User.fromJson(json['receiver']),
      message: json['message']?.toString() ?? '',
      isRead: json['is_read'] ?? false,
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      formattedCreatedAt: json['formatted_created_at']?.toString(),
    );
  }

  Chat copyWith({
    String? id,
    User? sender,
    User? receiver,
    String? message,
    bool? isRead,
    DateTime? readAt,
    DateTime? createdAt,
    String? formattedCreatedAt,
  }) {
    return Chat(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      receiver: receiver ?? this.receiver,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
      formattedCreatedAt: formattedCreatedAt ?? this.formattedCreatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender,
      'receiver': receiver,
      'message': message,
      'is_read': isRead,
      'read_at': readAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'formatted_created_at': formattedCreatedAt,
    };
  }
}
