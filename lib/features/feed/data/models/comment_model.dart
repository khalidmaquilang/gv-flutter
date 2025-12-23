import '../../../auth/data/models/user_model.dart';

class Comment {
  final String id;
  final User user;
  final String text;
  final DateTime createdAt;
  final int reactionsCount;
  final bool isReactedByUser;
  final String formattedCreatedAt;

  Comment({
    required this.id,
    required this.user,
    required this.text,
    required this.createdAt,
    this.reactionsCount = 0,
    this.isReactedByUser = false,
    this.formattedCreatedAt = '',
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'].toString(),
      user: User.fromJson(json['user']),
      text: json['message'] ?? json['text'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      reactionsCount: json['reactions_count'] ?? 0,
      isReactedByUser: json['is_reacted_by_user'] ?? false,
      formattedCreatedAt: json['formatted_created_at'] ?? '',
    );
  }
}
