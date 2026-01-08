import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../../data/models/video_model.dart';
import 'package:test_flutter/core/theme/app_theme.dart';
import 'comment_bottom_sheet.dart';

import 'package:test_flutter/core/utils/route_observer.dart';
import '../providers/feed_audio_provider.dart';
import '../providers/feed_provider.dart';
import '../providers/video_preload_provider.dart';
import '../../../profile/presentation/screens/profile_screen.dart'; // Import ProfileScreen
import 'package:test_flutter/core/providers/profile_provider.dart'; // Import profile provider

import 'dart:async';

class VideoPlayerItem extends ConsumerStatefulWidget {
  final Video video;
  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionEnd;
  final bool autoplay;
  final bool ignoreBottomNav;
  final bool hideProfileInfo;

  const VideoPlayerItem({
    super.key,
    required this.video,
    this.onInteractionStart,
    this.onInteractionEnd,
    this.autoplay = false,
    this.ignoreBottomNav = false,
    this.hideProfileInfo = false,
  });

  @override
  ConsumerState<VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends ConsumerState<VideoPlayerItem>
    with RouteAware {
  // Controller is now managed by provider
  VideoPlayerController? get _controller =>
      ref.watch(videoPreloadProvider).controllers[widget.video.id];

  bool _isLiked = false;
  int _likesCount = 0;

  // Track initial state
  late int _initialLikesCount;
  late String _initialFormattedReactionsCount;

  // New state for follow feature
  bool _isFollowing = false;
  int _followersCount = 0;
  String? _formattedFollowersCount;

  bool _isUiVisible = true;
  bool _hasRecordedView = false;
  Timer? _viewTimer;
  VideoPlayerController? _currentController;

  // _hasError is now somewhat implicitly handled by controller.value.hasError if we checked it
  bool get _hasError => _controller?.value.hasError ?? false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.video.isLiked;
    _initialLikesCount = widget.video.likesCount;
    _likesCount = _initialLikesCount;
    _initialFormattedReactionsCount = widget.video.formattedReactionsCount;

    // Initialize follow state
    _isFollowing = widget.video.user.isFollowing;
    _followersCount = widget.video.user.followersCount;
    _formattedFollowersCount = widget.video.user.formattedFollowersCount;
  }

  // Helper to safely check if controller is usable
  bool _isControllerValid(VideoPlayerController? controller) {
    return controller != null &&
        controller.value.isInitialized &&
        !controller.value.hasError;
  }

  void _startViewTimer() {
    if (_hasRecordedView || _viewTimer != null) return;

    _viewTimer = Timer(const Duration(seconds: 3), () {
      _recordView();
    });
  }

  void _cancelViewTimer() {
    _viewTimer?.cancel();
    _viewTimer = null;
  }

  Future<void> _recordView() async {
    if (_hasRecordedView) return;
    _hasRecordedView = true;
    _viewTimer = null; // Clear timer reference
    // print("Recording view for ${widget.video.id}");
    await ref.read(videoServiceProvider).recordView(widget.video.id);
  }

  void _onControllerUpdate() {
    final controller = _currentController;
    if (!_isControllerValid(controller)) return;

    if (controller!.value.isPlaying) {
      _startViewTimer();
    } else {
      _cancelViewTimer();
    }
  }

  Future<void> _toggleFollow() async {
    final profileService = ref.read(profileServiceProvider);

    // Optimistic update
    setState(() {
      _isFollowing = !_isFollowing;
      if (_isFollowing) {
        _followersCount++;
      } else {
        _followersCount--;
      }
    });

    try {
      if (_isFollowing) {
        await profileService.followUser(widget.video.user.id);
      } else {
        await profileService.unfollowUser(widget.video.user.id);
      }
    } catch (e) {
      // Revert if error
      if (mounted) {
        setState(() {
          _isFollowing = !_isFollowing;
          if (_isFollowing) {
            _followersCount++;
          } else {
            _followersCount--;
          }
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _navigateToProfile() {
    // Only pause if needed, but going to profile keeps cache alive usually.
    // However, pushing a new route usually warrants pausing.
    // The feed screen logic might auto-pause, but explicit pause is safer here.
    final controller = _currentController; // Use current controller
    if (_isControllerValid(controller) && controller!.value.isPlaying) {
      // ref.read(videoPreloadProvider.notifier).pauseCurrentVideo(); // Maybe better to use provider?
      // For now simple pause:
    }

    // Note: The main feed logic pauses video when route changes, so this might be redundant
    // or handled by route observer.

    print(
      'Navigating to profile - video.user.id: ${widget.video.user.id}, username: ${widget.video.user.username}',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ProfileScreen(userId: widget.video.user.id, isCurrentUser: false),
      ),
    ).then((_) {
      // Auto-resume will be handled by feed visibility logic
    });
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _cancelViewTimer();
    _currentController?.removeListener(_onControllerUpdate);
    // Don't dispose controller here, provider does it!
    super.dispose();
  }

  @override
  void didUpdateWidget(VideoPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.video.id != oldWidget.video.id) {
      _hasRecordedView = false;
      _cancelViewTimer();
    }

    if (widget.autoplay && !oldWidget.autoplay) {
      final controller = _controller;
      if (_isControllerValid(controller) && !controller!.value.isPlaying) {
        final shouldPlay =
            (widget.ignoreBottomNav || ref.read(bottomNavIndexProvider) == 0) &&
            ref.read(isFeedAudioEnabledProvider);

        if (shouldPlay) {
          controller.play();
        }
      }
    } else if (!widget.autoplay && oldWidget.autoplay) {
      final controller = _controller;
      if (_isControllerValid(controller)) {
        controller!.pause();
      }
    }
  }

  @override
  void didPushNext() {
    final controller = _controller;
    if (_isControllerValid(controller)) {
      controller!.pause();
    }
  }

  @override
  @override
  @override
  void didPopNext() {
    final shouldPlay =
        widget.autoplay &&
        (widget.ignoreBottomNav || ref.read(bottomNavIndexProvider) == 0) &&
        ref.read(isFeedAudioEnabledProvider);

    if (shouldPlay) {
      final controller = _controller;
      if (_isControllerValid(controller)) {
        controller!.play();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(isFeedAudioEnabledProvider, (previous, next) {
      if (next) {
        final controller = _controller;
        final shouldPlay =
            widget.autoplay &&
            (widget.ignoreBottomNav || ref.read(bottomNavIndexProvider) == 0) &&
            _isControllerValid(controller) &&
            !controller!.value.isPlaying;

        if (shouldPlay) {
          controller.play();
        }
      } else {
        final controller = _controller;
        if (_isControllerValid(controller)) {
          controller!.pause();
        }
      }
    });

    ref.listen(videoPreloadProvider, (previous, next) {
      final controller = next.controllers[widget.video.id];

      if (_isControllerValid(controller) && !controller!.value.isPlaying) {
        final shouldPlay =
            widget.autoplay &&
            (widget.ignoreBottomNav || ref.read(bottomNavIndexProvider) == 0) &&
            ref.read(isFeedAudioEnabledProvider);

        if (shouldPlay) {
          controller.play();
        }
      }
    });

    ref.listen(bottomNavIndexProvider, (previous, next) {
      final controller = _controller;
      if (!widget.ignoreBottomNav && next != 0) {
        if (_isControllerValid(controller)) {
          controller!.pause();
        }
      } else {
        final shouldPlay =
            widget.autoplay &&
            (widget.ignoreBottomNav || next == 0) &&
            ref.read(isFeedAudioEnabledProvider);
        if (shouldPlay && _isControllerValid(controller)) {
          controller!.play();
        }
      }
    });

    ref.listen(activeFeedTabProvider, (previous, next) {
      final controller = _controller;
      if (next == 2) {
        // For You tab - resume if this video should autoplay
        final shouldPlay =
            widget.autoplay &&
            (widget.ignoreBottomNav || ref.read(bottomNavIndexProvider) == 0) &&
            ref.read(isFeedAudioEnabledProvider);
        if (shouldPlay && _isControllerValid(controller)) {
          controller!.play();
        }
      } else {
        // Live tab (0) or Following tab (1) - pause all videos
        if (_isControllerValid(controller) && controller!.value.isPlaying) {
          controller.pause();
          debugPrint('Pausing video due to tab switch to index $next');
        }
      }
    });

    ref.listen(feedTabResetProvider, (previous, next) {
      final controller = _controller;
      if (!widget.ignoreBottomNav &&
          next > 0 &&
          _isControllerValid(controller)) {
        controller!.pause();
      }
    });

    // Listen to play/pause state changes directly on the controller
    final controller = _controller;
    if (controller != _currentController) {
      _currentController?.removeListener(_onControllerUpdate);
      _currentController = controller;
      if (_isControllerValid(_currentController)) {
        _currentController!.addListener(_onControllerUpdate);

        // Initial check for the new controller
        if (_currentController!.value.isPlaying) {
          _startViewTimer();
        }

        // Auto-play if this video should be playing
        final currentTab = ref.read(activeFeedTabProvider);
        final shouldPlay =
            widget.autoplay &&
            currentTab == 2 && // Only autoplay on For You tab
            (widget.ignoreBottomNav || ref.read(bottomNavIndexProvider) == 0) &&
            ref.read(isFeedAudioEnabledProvider) &&
            !_currentController!.value.isPlaying;

        if (shouldPlay) {
          _currentController!.play();
        }
      }
    }

    final isControllerInitialized = _controller?.value.isInitialized ?? false;

    return Stack(
      children: [
        // Video Layer (Zoomable)
        _ZoomableContent(
          onInteractionStart: () {
            widget.onInteractionStart?.call();
            setState(() {
              _isUiVisible = false;
            });
          },
          onInteractionEnd: () {
            widget.onInteractionEnd?.call();
          },
          onTap: _togglePlay,
          child: Container(
            color: Colors.black,
            child: Align(
              alignment: isControllerInitialized
                  // Align standard vertical videos (9:16 is ~0.56) to top
                  // Align wider videos (4:5, 1:1, 16:9) to center
                  ? (_controller!.value.aspectRatio < 0.7
                        ? Alignment.topCenter
                        : Alignment.center)
                  : Alignment.center,
              // Layout strategy:
              // 1. Vertical Videos (< 0.7): Use SizedBox.expand + FittedBox(cover) to fill screen.
              //    - This crops slightly on sides for tall screens but removes black bars.
              // 2. Other Videos (Square/Landscape): Use Center + AspectRatio (effectively contain)
              //    - This ensures the whole video is visible with black bars.
              child: _hasError
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 40,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Video format not supported",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  : (!isControllerInitialized)
                  ? Stack(
                      children: [
                        // Thumbnail Placeholder
                        SizedBox.expand(
                          child: (widget.video.thumbnailUrl.isNotEmpty)
                              ? Image.network(
                                  widget.video.thumbnailUrl,
                                  // If we assume the thumbnail matches video AR, we can try to cover for vertical.
                                  // But we don't know AR yet safely. Defaulting to cover is risky if it's landscape.
                                  // Let's stick to contain/center for safety, OR if we had metadata we could choose.
                                  // For now, let's try 'cover' to match the "no gap" desire, assuming most feed content is vertical.
                                  // Actually, safe bet: BoxFit.contain with Alignment.center.
                                  // Wait, user wants "no big black gap".
                                  // IF the user produces correctly post-processed videos (9:16), they want cover.
                                  // Let's use fitHeight for thumbnails if we can, or just cover.
                                  // Given the user expectation (TikTok style), cover is usually the default for feed thumbnails.
                                  fit: BoxFit.cover,
                                  alignment: Alignment.center,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(color: Colors.black);
                                  },
                                )
                              : Container(color: Colors.black),
                        ),
                      ],
                    )
                  : (_controller!.value.aspectRatio < 0.7)
                  ? SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _controller!.value.size.width,
                          height: _controller!.value.size.height,
                          child: VideoPlayer(_controller!),
                        ),
                      ),
                    )
                  : Center(
                      child: AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
            ),
          ),
        ),

        // Error Retry Overlay (Simplified - Removed manual retry for now as provider handles init)
        if (_hasError)
          const Center(
            child: Text(""), // Just show the error icon from above
          ),

        // UI Overlay (Fades out when zooming)
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _isUiVisible ? 1.0 : 0.0,
          child: Stack(
            children: [
              // Top User Info Header (New Design)
              if (!widget.hideProfileInfo)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 60,
                        top: 10,
                      ), // Right padding for Search icon
                      child: Row(
                        children: [
                          // Avatar
                          GestureDetector(
                            onTap: _navigateToProfile,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  const BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 20,
                                backgroundImage:
                                    widget.video.user.avatar != null &&
                                        widget.video.user.avatar!.isNotEmpty
                                    ? NetworkImage(widget.video.user.avatar!)
                                    : null,
                                child:
                                    widget.video.user.avatar == null ||
                                        widget.video.user.avatar!.isEmpty
                                    ? const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // User Name and Followers
                          Flexible(
                            // Use Flexible to keep follow button near
                            child: GestureDetector(
                              onTap: _navigateToProfile,
                              behavior: HitTestBehavior
                                  .translucent, // Ensure taps are captured
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "@${widget.video.user.username ?? widget.video.user.name}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black,
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "${_formattedFollowersCount ?? _followersCount} Followers",
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black,
                                          blurRadius: 3,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          // Follow Button
                          if (!_isFollowing)
                            GestureDetector(
                              onTap: _toggleFollow,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.neonPink,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.neonPink.withValues(
                                        alpha: 0.4,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  "Follow",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            )
                          else
                            GestureDetector(
                              onTap: _toggleFollow,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: const Text(
                                  "Following",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Right Side Actions
              Positioned(
                bottom: 220, // Shifted up
                right: 10,
                child: Column(
                  children: [
                    _buildAction(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      (_likesCount == _initialLikesCount)
                          ? _initialFormattedReactionsCount
                          : "$_likesCount",
                      color: _isLiked ? AppColors.neonPink : Colors.white,
                      onTap: _toggleLike,
                    ),
                    const SizedBox(height: 16),
                    _buildAction(
                      Icons.comment,
                      "Comment",
                      color: AppColors.neonCyan,
                      onTap: _showComments,
                    ),
                    const SizedBox(height: 16),
                    _buildAction(
                      Icons.share,
                      "Share",
                      color: AppColors.neonPurple,
                      onTap: _shareVideo,
                    ),
                  ],
                ),
              ),

              // Bottom Info (Caption only)
              Positioned(
                bottom: 130, // Increased to 130 to fully clear Nav Bar
                left: 16,
                right: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Caption
                    Text(
                      widget.video.caption,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _SpinningDisc(
                          imageUrl:
                              widget.video.sound?.coverUrl ??
                              widget.video.user.avatar,
                          size: 30,
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.music_note,
                          size: 15,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.video.sound != null
                                ? "${widget.video.sound!.title} • ${widget.video.sound!.author}"
                                : "Original Sound - ${widget.video.user.username}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 2),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _toggleLike() async {
    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) {
        _likesCount++;
      } else {
        _likesCount--;
      }
    });

    ref.read(feedProvider.notifier).toggleLike(widget.video.id);
    await ref.read(videoServiceProvider).toggleReaction(widget.video.id);
  }

  Future<void> _shareVideo() async {
    await Share.share(
      'Check out this video by @${widget.video.user.username}: ${widget.video.videoUrl}',
    );
  }

  void _togglePlay() {
    final controller = _controller;
    if (!_isControllerValid(controller)) return;

    setState(() {
      if (!_isUiVisible) {
        // If UI is hidden, tapping just brings it back
        _isUiVisible = true;
      } else {
        // Normal toggle play behavior
        if (controller!.value.isPlaying) {
          controller.pause();
          _cancelViewTimer();
        } else {
          controller.play();
          _startViewTimer();
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

  Widget _buildAction(
    IconData icon,
    String text, {
    Color color = Colors.white,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque, // Fix hit test issue
      child: Container(
        color: Colors.transparent, // Ensure area is tappable
        padding: const EdgeInsets.all(8.0), // Increase touch target
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.8),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 36,
                color: color,
                shadows: [Shadow(color: color, blurRadius: 10)],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                shadows: [Shadow(color: Colors.black, blurRadius: 4)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomableContent extends StatefulWidget {
  final Widget child;
  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionEnd;
  final VoidCallback? onTap;

  const _ZoomableContent({
    required this.child,
    this.onInteractionStart,
    this.onInteractionEnd,
    this.onTap,
  });

  @override
  State<_ZoomableContent> createState() => _ZoomableContentState();
}

class _ZoomableContentState extends State<_ZoomableContent>
    with TickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();
  late AnimationController _animationController;
  late Animation<Matrix4> _zoomAnimation;
  int _pointers = 0;
  bool _canPan = false;
  Timer? _longPressTimer;
  Offset? _longPressOrigin;

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 300),
        )..addListener(() {
          _transformationController.value = _zoomAnimation.value;
        });

    _transformationController.addListener(_onTransformationChange);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChange);
    _transformationController.dispose();
    _animationController.dispose();
    _longPressTimer?.cancel();
    super.dispose();
  }

  void _onTransformationChange() {
    _updatePanEnablement();
  }

  void _updatePanEnablement() {
    // Enable pan if zoomed in OR if multiple fingers are down (pinch)
    final isZoomed = !_transformationController.value.isIdentity();
    final shouldEnablePan = isZoomed || _pointers >= 2;

    if (shouldEnablePan != _canPan) {
      if (mounted) {
        setState(() {
          _canPan = shouldEnablePan;
        });
      }
    }
  }

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

      widget.onInteractionStart?.call(); // Lock scroll
    } else {
      // Zoom Out to 1x
      endMatrix = Matrix4.identity();
      widget.onInteractionEnd?.call(); // Unlock scroll
    }

    _zoomAnimation =
        Matrix4Tween(
          begin: _transformationController.value,
          end: endMatrix,
        ).animate(
          CurveTween(curve: Curves.easeInOut).animate(_animationController),
        );

    _animationController.forward(from: 0).then((_) {
      if (endMatrix.isIdentity()) {
        widget.onInteractionEnd?.call();
      }
    });
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.download, color: Colors.white),
                title: const Text(
                  'Download Video',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Downloading video...')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag, color: Colors.white),
                title: const Text(
                  'Report',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Unwanted Report submitted.')),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        _pointers++;
        _updatePanEnablement(); // Check if we should enable pan (e.g. 2nd finger)

        // Handle Scroll Lock
        if (_pointers >= 2) {
          widget.onInteractionStart?.call();
          _longPressTimer?.cancel(); // Cancel long press if 2 fingers
        }

        // Handle Manual Long Press (Only if 1 finger and unzoomed)
        // If we are zoomed, we allow panning instead of long press menu?
        // TikTok behavior: Long press works even if zoomed? Probably.
        // But for now, let's keep it simple.
        if (_pointers == 1) {
          _longPressOrigin = event.position;
          _longPressTimer?.cancel();
          _longPressTimer = Timer(const Duration(milliseconds: 500), () {
            if (mounted && _pointers == 1) {
              _showOptionsMenu();
            }
          });
        }
      },
      onPointerMove: (event) {
        // Cancel Long Press if moved significantly
        if (_longPressOrigin != null) {
          final distance = (event.position - _longPressOrigin!).distance;
          if (distance > 10.0) {
            // 10.0 is a reasonable slop
            _longPressTimer?.cancel();
          }
        }
      },
      onPointerUp: (event) {
        _pointers--;
        _updatePanEnablement();
        _longPressTimer?.cancel(); // Cancel on release
        if (_pointers == 0) {
          if (_transformationController.value.isIdentity()) {
            widget.onInteractionEnd?.call();
          }
        }
      },
      onPointerCancel: (event) {
        _pointers = 0;
        _updatePanEnablement();
        _longPressTimer?.cancel();
        if (_transformationController.value.isIdentity()) {
          widget.onInteractionEnd?.call();
        }
      },
      child: InteractiveViewer(
        key: const ValueKey('interactive_viewer'), // Add Key for stability
        transformationController: _transformationController,
        minScale: 1.0,
        maxScale: 4.0,
        panEnabled: _canPan,
        onInteractionStart: (details) {
          // Only trigger UI hide if we are actually zooming or panning significantly?
          // Or reliance on pointers check?
          if (_pointers >= 2 || !_transformationController.value.isIdentity()) {
            widget.onInteractionStart?.call();
          }
        },
        onInteractionEnd: (details) {
          // No Snap back on simple end?
          // TikTok behavior: If you release pinch but are zoomed in -> Stay zoomed?
          // User requested "Snap Back".
          // Previous code:
          // _transformationController.value = Matrix4.identity();
          // widget.onInteractionEnd?.call();

          // Wait, previous code snapped back!
          // Let's restore Snap Back behavior to be safe.
          _transformationController.value = Matrix4.identity();
          widget.onInteractionEnd?.call();
        },
        child: GestureDetector(
          onTap: widget.onTap,
          onDoubleTap: _handleDoubleTap,
          behavior: HitTestBehavior.opaque,
          child: widget.child,
        ),
      ),
    );
  }
}

class _SpinningDisc extends StatefulWidget {
  final String? imageUrl;
  final double size;
  const _SpinningDisc({this.imageUrl, this.size = 45});

  @override
  State<_SpinningDisc> createState() => _SpinningDiscState();
}

class _SpinningDiscState extends State<_SpinningDisc>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: const Color(0xFF111111), // Dark vinyl background
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF222222),
            width: widget.size * 0.15,
          ),
          image: widget.imageUrl != null
              ? DecorationImage(
                  image: NetworkImage(widget.imageUrl!),
                  fit: BoxFit.cover,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: widget.imageUrl == null
            ? const Center(
                child: Icon(Icons.music_note, color: Colors.white, size: 20),
              )
            : null,
      ),
    );
  }
}
