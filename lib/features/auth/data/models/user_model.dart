class User {
  final String id;
  final String name;
  final String? username;
  final String? email;
  final String? avatar;
  final String? bio;
  final bool isFollowing;
  final bool
  youAreFollowed; // Whether the profile owner follows the viewing user
  final bool allowLive;
  final int followersCount;
  final String? formattedFollowersCount;
  final int followingCount;
  final String? formattedFollowingCount;
  final int likesCount;
  final String? formattedLikesCount;

  User({
    required this.id,
    required this.name,
    this.username,
    this.email,
    this.avatar,
    this.bio,
    this.isFollowing = false,
    this.youAreFollowed = false,
    this.allowLive = false,
    this.followersCount = 0,
    this.formattedFollowersCount,
    this.followingCount = 0,
    this.formattedFollowingCount,
    this.likesCount = 0,
    this.formattedLikesCount,
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
      youAreFollowed: json['you_are_followed'] ?? false,
      allowLive: json['allow_live'] ?? false,
      followersCount: json['followers_count'] ?? 0,
      formattedFollowersCount: json['formatted_followers_count'],
      followingCount: json['following_count'] ?? 0,
      formattedFollowingCount: json['formatted_following_count'],
      likesCount: json['likes_count'] ?? 0,
      formattedLikesCount: json['formatted_likes_count'],
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
      'you_are_followed': youAreFollowed,
      'allow_live': allowLive,
      'followers_count': followersCount,
      'formatted_followers_count': formattedFollowersCount,
      'following_count': followingCount,
      'formatted_following_count': formattedFollowingCount,
      'likes_count': likesCount,
      'formatted_likes_count': formattedLikesCount,
    };
  }
}
