import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../../data/models/video_model.dart';
import 'package:test_flutter/core/theme/app_theme.dart';
import '../../data/services/video_service.dart';
import 'comment_bottom_sheet.dart';

class VideoPlayerItem extends ConsumerStatefulWidget {
  final Video video;
  const VideoPlayerItem({super.key, required this.video});

  @override
  ConsumerState<VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends ConsumerState<VideoPlayerItem> {
  late VideoPlayerController _controller;
  bool _isLoading = true;
  bool _isLiked = false;
  int _likesCount = 0;
  final VideoService _videoService = VideoService(); // Should use provider

  @override
  void initState() {
    super.initState();
    _isLiked = widget.video.isLiked;
    _likesCount = widget.video.likesCount;
    _controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.video.videoUrl))
          ..initialize()
              .then((_) {
                if (!mounted) {
                  // Widget was disposed while loading
                  return;
                }
                setState(() {
                  _isLoading = false;
                });
                _controller.play();
                _controller.setLooping(true);
              })
              .catchError((error) {
                // Handle error
                debugPrint("Video Error: $error");
              });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });

    if (_isLiked) {
      await _videoService.likeVideo(widget.video.id);
    } else {
      await _videoService.unlikeVideo(widget.video.id);
    }
  }

  Future<void> _shareVideo() async {
    await Share.share(
      'Check out this video by @${widget.video.user.name}: ${widget.video.videoUrl}',
    );
  }

  void _togglePlay() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentBottomSheet(videoId: widget.video.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(bottomNavIndexProvider, (previous, next) {
      if (!_controller.value.isInitialized) return;

      if (next != 0) {
        // Not on Feed
        _controller.pause();
      } else {
        // Returned to Feed - Resume
        // Note: For better UX, we might want to check if it was manually paused
        _controller.play();
      }
    });

    return Stack(
      children: [
        // Video Layer
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            color: Colors.black,
            child: Center(
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
            ),
          ),
        ),
        // Right Side Actions (Avatar, Like, Comment, Share)
        Positioned(
          bottom: 100,
          right: 10,
          child: Column(
            children: [
              _buildAction(
                _isLiked ? Icons.favorite : Icons.favorite_border,
                "$_likesCount",
                color: _isLiked ? AppColors.neonPink : Colors.white,
                onTap: _toggleLike,
              ),
              const SizedBox(height: 16),
              _buildAction(
                Icons.comment,
                "${widget.video.commentsCount}",
                onTap: _showComments,
              ),
              const SizedBox(height: 16),
              _buildAction(Icons.share, "Share", onTap: _shareVideo),
            ],
          ),
        ),

        // Bottom Info (Name, Caption)
        Positioned(
          bottom: 20,
          left: 10,
          right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "@${widget.video.user.name}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.video.caption,
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAction(
    IconData icon,
    String text, {
    Color color = Colors.white,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 36, color: color),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(fontSize: 12, color: Colors.white)),
        ],
      ),
    );
  }
}
