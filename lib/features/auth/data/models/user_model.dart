class User {
  final String id;
  final String name;
  final String? username;
  final String? email;
  final String? avatar;
  final String? bio;
  final bool isFollowing;
  final int followersCount;
  final int followingCount;
  final int likesCount;

  User({
    required this.id,
    required this.name,
    this.username,
    this.email,
    this.avatar,
    this.bio,
    this.isFollowing = false,
    this.followersCount = 0,
    this.followingCount = 0,
    this.likesCount = 0,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'].toString(),
      name: json['name'],
      username: json['username'],
      email: json['email'],
      avatar: json['avatar'],
      bio: json['bio'],
      isFollowing: json['is_following'] ?? false,
      followersCount: json['followers_count'] ?? 0,
      followingCount: json['following_count'] ?? 0,
      likesCount: json['likes_count'] ?? 0,
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
      'is_following': isFollowing,
      'followers_count': followersCount,
      'following_count': followingCount,
      'likes_count': likesCount,
    };
  }
}
