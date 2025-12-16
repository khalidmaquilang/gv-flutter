class User {
  final String id;
  final String name;
  final String? username;
  final String email;
  final String? avatar;
  final String? bio;

  User({
    required this.id,
    required this.name,
    this.username,
    required this.email,
    this.avatar,
    this.bio,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'].toString(),
      name: json['name'],
      username: json['username'],
      email: json['email'],
      avatar: json['avatar'],
      bio: json['bio'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'email': email,
      'avatar': avatar,
      'bio': bio,
    };
  }
}
