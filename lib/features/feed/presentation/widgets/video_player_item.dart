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

import 'dart:async';

class VideoPlayerItem extends ConsumerStatefulWidget {
  final Video video;
  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionEnd;

  const VideoPlayerItem({
    super.key,
    required this.video,
    this.onInteractionStart,
    this.onInteractionEnd,
    this.autoplay = false,
    this.shouldPrepare = false,
  });

  final bool autoplay;
  final bool shouldPrepare;

  @override
  ConsumerState<VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends ConsumerState<VideoPlayerItem>
    with RouteAware {
  VideoPlayerController? _controller;

  bool _isLoading = true;
  bool _isLiked = false;
  int _likesCount = 0;
  final VideoService _videoService = VideoService();

  bool _isUiVisible = true;
  bool _hasError = false;

  @override
  void didUpdateWidget(VideoPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Autoplay handling
    if (widget.autoplay != oldWidget.autoplay) {
      if (widget.autoplay) {
        _controller?.play();
      } else {
        _controller?.pause();
      }
    }

    // Lazy Loading Handling
    if (widget.shouldPrepare != oldWidget.shouldPrepare) {
      if (widget.shouldPrepare) {
        _initializeController();
      } else {
        _disposeController();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _isLiked = widget.video.isLiked;
    _likesCount = widget.video.likesCount;

    if (widget.shouldPrepare) {
      _initializeController();
    }
  }

  void _initializeController() {
    if (_controller != null) return;

    print(
      "VideoPlayerItem: Init ${widget.video.id}, URL: ${widget.video.videoUrl}",
    );

    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.video.videoUrl),
    );

    _controller!
        .initialize()
        .then((_) {
          if (!mounted) {
            // print("VideoPlayerItem: Init success but unmounted ${widget.video.id}");
            return;
          }
          // print("VideoPlayerItem: Init success ${widget.video.id}");
          setState(() {
            _isLoading = false;
            _hasError = false;
          });
          if (widget.autoplay ||
              (ref.read(bottomNavIndexProvider) == 0 &&
                  ref.read(isFeedAudioEnabledProvider))) {
            _controller?.play();
          }
          _controller?.setLooping(true);
        })
        .catchError((error) {
          // print("VideoPlayerItem: Init Failed ${widget.video.id}, Error: $error");
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
          debugPrint("Video Error: $error");
        });
  }

  void _disposeController() {
    if (_controller == null) return;
    // print("VideoPlayerItem: Disposing controller ${widget.video.id}");
    _controller?.dispose();
    _controller = null;
    if (mounted) {
      setState(() {
        _isLoading = true; // Show loading when re-initializing
      });
    }
  }

  @override
  void dispose() {
    // print("VideoPlayerItem: Dispose Object ${widget.video.id}");
    routeObserver.unsubscribe(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didPushNext() {
    _controller?.pause();
  }

  @override
  void didPopNext() {
    if (widget.autoplay ||
        (ref.read(bottomNavIndexProvider) == 0 &&
            ref.read(isFeedAudioEnabledProvider))) {
      _controller?.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(isFeedAudioEnabledProvider, (previous, next) {
      if (next) {
        if (ref.read(bottomNavIndexProvider) == 0 &&
            _controller != null &&
            !_controller!.value.isPlaying) {
          _controller?.play();
        }
      } else {
        _controller?.pause();
      }
    });

    ref.listen(bottomNavIndexProvider, (previous, next) {
      if (next != 0) {
        _controller?.pause();
      } else {
        if (ref.read(isFeedAudioEnabledProvider)) {
          _controller?.play();
        }
      }
    });

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
            child: Center(
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
                  : (_isLoading || _controller == null)
                  ? Stack(
                      children: [
                        // Thumbnail Placeholder
                        SizedBox.expand(
                          child: (widget.video.thumbnailUrl.isNotEmpty)
                              ? Image.network(
                                  widget.video.thumbnailUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(color: Colors.black);
                                  },
                                )
                              : Container(color: Colors.black),
                        ),
                      ],
                    )
                  : AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
            ),
          ),
        ),

        // UI Overlay (Fades out when zooming)
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _isUiVisible ? 1.0 : 0.0,
          child: Stack(
            children: [
              // Right Side Actions (Avatar, Like, Comment, Share)
              Positioned(
                bottom: 160, // Moved up further as requested
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
                      "Comment",
                      color: AppColors.neonCyan, // Cyan for comments
                      onTap: _showComments,
                    ),
                    const SizedBox(height: 16),
                    _buildAction(
                      Icons.share,
                      "Share",
                      color: AppColors.neonPurple, // Purple for share
                      onTap: _shareVideo,
                    ),
                  ],
                ),
              ),

              // Bottom Info (Name, Caption)
              Positioned(
                bottom: 130, // Kept at 130
                left: 16, // Standard left padding
                right: 80, // Reduced right padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "@${widget.video.user.name}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: AppColors.neonCyan, blurRadius: 4),
                          Shadow(color: Colors.black, blurRadius: 2),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.video.caption,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                      ),
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
                                : "Original Sound - ${widget.video.user.name}",
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
        if (_controller != null && _controller!.value.isPlaying) {
          _controller?.pause();
        } else {
          _controller?.play();
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
          widget.onInteractionStart?.call();
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
              color: Colors.black.withOpacity(0.5),
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
