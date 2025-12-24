import '../../../auth/data/models/user_model.dart';

class Comment {
  final String id;
  final User user;
  final String text;
  final DateTime createdAt;
  final int reactionsCount;
  final bool isReactedByUser;
  final String formattedCreatedAt;
  final String formattedReactionsCount;

  Comment({
    required this.id,
    required this.user,
    required this.text,
    required this.createdAt,
    this.reactionsCount = 0,
    this.isReactedByUser = false,
    this.formattedCreatedAt = '',
    this.formattedReactionsCount = '0',
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
      formattedReactionsCount:
          json['formatted_reactions_count']?.toString() ?? '0',
    );
  }
  Comment copyWith({
    String? id,
    User? user,
    String? text,
    DateTime? createdAt,
    int? reactionsCount,
    bool? isReactedByUser,
    String? formattedCreatedAt,
    String? formattedReactionsCount,
  }) {
    return Comment(
      id: id ?? this.id,
      user: user ?? this.user,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      reactionsCount: reactionsCount ?? this.reactionsCount,
      isReactedByUser: isReactedByUser ?? this.isReactedByUser,
      formattedCreatedAt: formattedCreatedAt ?? this.formattedCreatedAt,
      formattedReactionsCount:
          formattedReactionsCount ?? this.formattedReactionsCount,
    );
  }
}
