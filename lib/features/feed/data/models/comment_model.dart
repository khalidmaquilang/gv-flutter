import '../../../auth/data/models/user_model.dart';

class Comment {
  final int id;
  final User user;
  final String text;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.user,
    required this.text,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      user: User.fromJson(json['user']),
      text: json['text'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
