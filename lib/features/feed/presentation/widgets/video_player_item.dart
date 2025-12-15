import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../../data/models/video_model.dart';
import 'package:test_flutter/core/theme/app_theme.dart';
import '../../data/services/video_service.dart';
import 'comment_bottom_sheet.dart';

import 'package:test_flutter/core/utils/route_observer.dart';
import '../providers/feed_audio_provider.dart';

class VideoPlayerItem extends ConsumerStatefulWidget {
  final Video video;
  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionEnd;

  const VideoPlayerItem({
    super.key,
    required this.video,
    this.onInteractionStart,
    this.onInteractionEnd,
  });

  @override
  ConsumerState<VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends ConsumerState<VideoPlayerItem>
    with RouteAware, TickerProviderStateMixin {
  late VideoPlayerController _controller;
  // ... (keep existing fields)
  bool _isLoading = true;
  bool _isLiked = false;
  int _likesCount = 0;
  final VideoService _videoService = VideoService();

  final TransformationController _transformationController =
      TransformationController();
  late AnimationController _animationController;
  late Animation<Matrix4> _zoomAnimation;
  bool _isUiVisible = true;
  int _pointers = 0;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.video.isLiked;
    _likesCount = widget.video.likesCount;

    _animationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 300),
        )..addListener(() {
          _transformationController.value = _zoomAnimation.value;
        });

    _controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.video.videoUrl))
          ..initialize()
              .then((_) {
                if (!mounted) return;
                setState(() {
                  _isLoading = false;
                });
                if (ref.read(bottomNavIndexProvider) == 0 &&
                    ref.read(isFeedAudioEnabledProvider)) {
                  _controller.play();
                }
                _controller.setLooping(true);
              })
              .catchError((error) {
                debugPrint("Video Error: $error");
              });
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _controller.dispose();
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ... (keep listeners and other methods)

  void _handleDoubleTap() {
    Matrix4 endMatrix;
    if (_transformationController.value.isIdentity()) {
      // Zoom In to 2x at Center
      final size = MediaQuery.of(context).size;
      final center = size.center(Offset.zero);

      // Matrix: Translate(Center) * Scale(2) * Translate(-Center)
      endMatrix = Matrix4.identity()
        ..translate(center.dx, center.dy)
        ..scale(2.0)
        ..translate(-center.dx, -center.dy);

      // Hide UI when we start zooming in
      setState(() {
        _isUiVisible = false;
      });
      widget.onInteractionStart?.call(); // Lock scroll
    } else {
      // Zoom Out to 1x
      endMatrix = Matrix4.identity();
      widget.onInteractionEnd
          ?.call(); // Unlock scroll (will be handled by animation completion?)
      // Actually consistent with pinch behavior: snap back resets state
    }

    _zoomAnimation =
        Matrix4Tween(
          begin: _transformationController.value,
          end: endMatrix,
        ).animate(
          CurveTween(curve: Curves.easeInOut).animate(_animationController),
        );

    _animationController.forward(from: 0).then((_) {
      // If we zoomed out completely, ensure state is clean
      if (endMatrix.isIdentity()) {
        // We could restore UI here if we wanted "Double Tap to Reset" to also show UI
        // But based on "Clean Mode", we might let it stay hidden or not?
        // Let's restore scroll lock at least.
        widget.onInteractionEnd?.call();
      }
    });
  }

  // ... (keep _togglePlay)

  @override
  Widget build(BuildContext context) {
    // ... (keep listeners)
    ref.listen(isFeedAudioEnabledProvider, (previous, next) {
      if (next) {
        if (ref.read(bottomNavIndexProvider) == 0 &&
            !_controller.value.isPlaying) {
          _controller.play();
        }
      } else {
        _controller.pause();
      }
    });

    ref.listen(bottomNavIndexProvider, (previous, next) {
      if (next != 0) {
        _controller.pause();
      } else {
        if (ref.read(isFeedAudioEnabledProvider)) {
          _controller.play();
        }
      }
    });

    return Listener(
      onPointerDown: (_) {
        _pointers++;
        if (_pointers >= 2) {
          widget.onInteractionStart?.call();
        }
      },
      onPointerUp: (_) {
        _pointers--;
        if (_pointers == 0 && _isUiVisible) {
          widget.onInteractionEnd?.call();
        }
      },
      onPointerCancel: (_) {
        _pointers = 0;
        if (_isUiVisible) widget.onInteractionEnd?.call();
      },
      child: Stack(
        children: [
          // Video Layer (Zoomable)
          InteractiveViewer(
            transformationController: _transformationController,
            minScale: 1.0,
            maxScale: 4.0,
            onInteractionStart: _onInteractionStart,
            onInteractionEnd: _onInteractionEnd,
            child: GestureDetector(
              onTap: _togglePlay,
              onDoubleTap: _handleDoubleTap,
              behavior: HitTestBehavior.opaque,
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
          ),

          // ... (keep UI Overlay code same as before, just ensure it wraps correctly)
          // Since I cannot match the huge block easily if I change too much, I will focus on the start of class and build method updates
          // But I need to include the UI overlay part in ReplacementContent if I replace the whole build method.
          // Let's try to replace just chunks if possible, or the whole class if easier.
          // The previous file content tool output shows lines 30-285. I'll replace the state class implementation.

          // UI Overlay (Fades out when zooming)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _isUiVisible ? 1.0 : 0.0,
            child: Stack(
              children: [
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
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
      if (!_isUiVisible) {
        // If UI is hidden, tapping just brings it back
        _isUiVisible = true;
      } else {
        // Normal toggle play behavior
        if (_controller.value.isPlaying) {
          _controller.pause();
        } else {
          _controller.play();
        }
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

  void _onInteractionStart(ScaleStartDetails details) {
    widget.onInteractionStart?.call();
    setState(() {
      _isUiVisible = false;
    });
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    widget.onInteractionEnd?.call();
    // Snap back to original size
    _transformationController.value = Matrix4.identity();
    // Note: We do NOT restore UI here, effectively entering "Clean Mode"
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
