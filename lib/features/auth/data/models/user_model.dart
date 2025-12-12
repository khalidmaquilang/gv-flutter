class User {
  final int id;
  final String name;
  final String email;
  final String? avatar;
  final String? bio;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
    this.bio,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      avatar: json['avatar_url'],
      bio: json['bio'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatar_url': avatar,
      'bio': bio,
    };
  }
}
