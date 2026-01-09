import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class UserSearchResultItem extends StatelessWidget {
  // These fields represent the data query requirements for search results
  final String username;
  final String name;
  final String avatarUrl;
  final String followersCount;
  final bool isFollowing;

  const UserSearchResultItem({
    super.key,
    required this.username,
    required this.name,
    required this.avatarUrl,
    required this.followersCount,
    this.isFollowing = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
        backgroundColor: Colors.grey[800],
        child: avatarUrl.isEmpty
            ? const Icon(Icons.person, color: Colors.white)
            : null,
      ),
      title: Text(
        name,
        style: const TextStyle(
          color: AppColors.textMain,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "@$username",
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(
            "$followersCount followers",
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
      trailing: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: isFollowing
              ? Colors.grey[800]
              : AppColors.neonPink, // Brand color
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: isFollowing
                ? BorderSide(color: Colors.grey[700]!)
                : BorderSide.none,
          ),
          minimumSize: const Size(80, 32),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Text(
          isFollowing ? "Following" : "Follow",
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
