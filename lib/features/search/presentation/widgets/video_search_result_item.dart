import 'package:flutter/material.dart';

class VideoSearchResultItem extends StatelessWidget {
  // Required Data Fields
  final String thumbnailUrl;
  final String viewsCount;
  final String userAvatarUrl;
  final String username;

  const VideoSearchResultItem({
    super.key,
    required this.thumbnailUrl,
    required this.viewsCount,
    required this.userAvatarUrl,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Thumbnail
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            image: thumbnailUrl.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(thumbnailUrl),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
        ),

        // Gradient Overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
              stops: const [0.7, 1.0],
            ),
          ),
        ),

        // Views Count (Bottom Left)
        Positioned(
          bottom: 8,
          left: 8,
          child: Row(
            children: [
              const Icon(
                Icons.play_arrow_outlined,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                viewsCount,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // User Avatar (Bottom Right - Optional/Design Choice)
        // Usually search grids are dense, so maybe just views is enough?
        // But adding user gives more context.
        Positioned(
          bottom: 8,
          right: 8,
          child: Row(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundImage: NetworkImage(userAvatarUrl),
                backgroundColor: Colors.grey[800],
              ),
              const SizedBox(width: 4),
              Text(
                username,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
