import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/video_model.dart';
import '../../../live/presentation/screens/live_stream_screen.dart';

class LivePreviewItem extends ConsumerWidget {
  final Video video;
  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionEnd;

  const LivePreviewItem({
    super.key,
    required this.video,
    this.onInteractionStart,
    this.onInteractionEnd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If not a live stream or not started, show placeholder
    if (!video.isLiveBroadcasting) {
      return _buildPlaceholder(context);
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LiveStreamScreen(
              isBroadcaster: false,
              channelId: video.streamKey!,
            ),
          ),
        );
      },
      child: Stack(
        children: [
          // Static thumbnail background
          Container(
            color: Colors.black,
            child: video.thumbnailUrl.isNotEmpty
                ? Image.network(
                    video.thumbnailUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildFallbackBackground();
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return _buildFallbackBackground();
                    },
                  )
                : _buildFallbackBackground(),
          ),

          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.5),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // LIVE badge with pulse animation
          Positioned(top: 16, left: 16, child: _PulsatingLiveBadge()),

          // Viewers count
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.neonCyan.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.remove_red_eye,
                    color: AppColors.neonCyan,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${video.views}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Center user avatar instead of play button
          Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.neonCyan, AppColors.neonPink],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.neonCyan.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 50,
                backgroundImage: video.user.avatar != null
                    ? NetworkImage(video.user.avatar!)
                    : null,
                backgroundColor: AppColors.deepVoid,
                child: video.user.avatar == null
                    ? Text(
                        video.user.name[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
            ),
          ),

          // Bottom info - adjusted padding to avoid navigation overlap
          Positioned(
            bottom: 140, // Increased from 16 to avoid bottom navigation
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '@${video.user.username ?? video.user.name}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(color: AppColors.neonCyan, blurRadius: 6),
                      Shadow(color: Colors.black, blurRadius: 3),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  video.caption,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    shadows: [Shadow(color: Colors.black, blurRadius: 3)],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap to join live stream',
                  style: TextStyle(
                    color: AppColors.neonCyan.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.deepVoid,
            AppColors.deepVoid.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.live_tv,
          size: 80,
          color: AppColors.neonPink.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam_off,
              size: 60,
              color: AppColors.neonPink.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              video.startedAt == null
                  ? 'Stream not started yet'
                  : 'Stream ended',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              video.caption,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Pulsating LIVE badge widget
class _PulsatingLiveBadge extends StatefulWidget {
  @override
  State<_PulsatingLiveBadge> createState() => _PulsatingLiveBadgeState();
}

class _PulsatingLiveBadgeState extends State<_PulsatingLiveBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.neonPink,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: AppColors.neonPink.withValues(alpha: _animation.value),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: _animation.value),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
