import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as mk_video;
import 'package:share_plus/share_plus.dart';
import '../../data/models/video_model.dart';
import '../providers/media_kit_video_provider.dart';
import '../providers/feed_audio_provider.dart';
import '../providers/feed_provider.dart';
import '../../data/services/video_service.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../camera/data/models/sound_model.dart';
import '../screens/music_detail_screen.dart';
import 'comment_bottom_sheet.dart';

/// MediaKit video player with UI overlay
class MediaKitVideoPlayerItem extends ConsumerStatefulWidget {
  final Video video;
  final VoidCallback? onInteractionStart;
  final VoidCallback? onInteractionEnd;
  final bool autoplay;
  final bool ignoreBottomNav;

  const MediaKitVideoPlayerItem({
    super.key,
    required this.video,
    this.onInteractionStart,
    this.onInteractionEnd,
    this.autoplay = false,
    this.ignoreBottomNav = false,
  });

  @override
  ConsumerState<MediaKitVideoPlayerItem> createState() =>
      _MediaKitVideoPlayerItemState();
}

class _MediaKitVideoPlayerItemState
    extends ConsumerState<MediaKitVideoPlayerItem> {
  Player? get _player =>
      ref.watch(mediaKitVideoProvider).players[widget.video.id];
  mk_video.VideoController? get _controller =>
      ref.watch(mediaKitVideoProvider).controllers[widget.video.id];

  // Follow state
  bool _isFollowing = false;
  int _followersCount = 0;
  String? _formattedFollowersCount;

  // Like state
  bool _isLiked = false;
  int _likesCount = 0;
  int _initialLikesCount = 0;
  String _initialFormattedReactionsCount = "";

  // View tracking
  Timer? _viewTimer;
  bool _hasRecordedView = false;
  int _cumulativeWatchTimeMs = 0; // Track total watch time for short videos
  DateTime? _lastPlayTime;

  @override
  void initState() {
    super.initState();
    // Initialize follow state from video
    _isFollowing = widget.video.isAuthorFollowedByUser;
    _followersCount = widget.video.user.followersCount;
    _formattedFollowersCount = widget.video.user.formattedFollowersCount;

    // Initialize like state from video
    _isLiked = widget.video.isLiked;
    _likesCount = widget.video.likesCount;
    _initialLikesCount = widget.video.likesCount;
    _initialFormattedReactionsCount = widget.video.formattedReactionsCount;
  }

  @override
  void dispose() {
    _cancelViewTimer();
    super.dispose();
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

  void _startViewTimer() {
    if (_hasRecordedView) return;

    // Start tracking watch time
    _lastPlayTime = DateTime.now();
    print('DEBUG VIEW: Started tracking time for video ${widget.video.id}');

    // For short videos (< 2 sec), we'll track cumulative time in build()
    // For normal videos (>= 2 sec), use a simple timer
    final videoDuration = _player?.state.duration ?? Duration.zero;
    print('DEBUG VIEW: Video duration: ${videoDuration.inSeconds}s');

    if (videoDuration.inSeconds >= 2) {
      // Normal video: simple 2-second timer
      if (_viewTimer == null) {
        print('DEBUG VIEW: Setting 2-second timer');
        _viewTimer = Timer(const Duration(seconds: 2), () {
          print('DEBUG VIEW: Timer fired! Recording view...');
          _recordView();
        });
      }
    } else {
      print('DEBUG VIEW: Short video, using cumulative tracking');
    }
    // For short videos, we'll check cumulative time in build()
  }

  void _cancelViewTimer() {
    // Update cumulative watch time before cancelling
    if (_lastPlayTime != null && !_hasRecordedView && mounted) {
      final elapsed = DateTime.now().difference(_lastPlayTime!);
      _cumulativeWatchTimeMs += elapsed.inMilliseconds;
      _lastPlayTime = null;

      print('DEBUG VIEW: Cumulative time: ${_cumulativeWatchTimeMs}ms');

      // Check if we've watched enough total time (2 seconds)
      if (_cumulativeWatchTimeMs >= 2000) {
        print('DEBUG VIEW: Cumulative threshold reached! Recording view...');
        _recordView();
      }
    }

    _viewTimer?.cancel();
    _viewTimer = null;
  }

  Future<void> _recordView() async {
    if (_hasRecordedView || !mounted) return;
    _hasRecordedView = true;
    _viewTimer = null;
    print('DEBUG VIEW: Recording view for video ${widget.video.id}');
    await ref.read(videoServiceProvider).recordView(widget.video.id);
    print('DEBUG VIEW: View recorded successfully!');
  }

  Widget _buildAction(
    IconData icon,
    String text, {
    Color color = Colors.white,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.all(8.0),
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

  void _navigateToProfile() {
    // Pause ALL players unconditionally to ensure no background audio
    final provider = ref.read(mediaKitVideoProvider);
    print('DEBUG: Total players: ${provider.players.length}');
    for (final entry in provider.players.entries) {
      print(
        'DEBUG: Pausing player for video ${entry.key} (playing: ${entry.value.state.playing})',
      );
      entry.value.pause();
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ProfileScreen(userId: widget.video.user.id, isCurrentUser: false),
      ),
    ).then((_) {
      // Resume if this is the current video (autoplay=true) and conditions are met
      final player = ref.read(mediaKitVideoProvider).players[widget.video.id];
      if (widget.autoplay && player != null && !player.state.playing) {
        final bottomNav = ref.read(bottomNavIndexProvider);
        final audioEnabled = ref.read(isFeedAudioEnabledProvider);
        final currentTab = ref.read(activeFeedTabProvider);

        if ((widget.ignoreBottomNav || bottomNav == 0) &&
            audioEnabled &&
            (currentTab == 1 || currentTab == 2)) {
          player.play();
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

  void _navigateToMusicDetail() {
    // Pause ALL players unconditionally to ensure no background audio
    final provider = ref.read(mediaKitVideoProvider);
    for (final entry in provider.players.entries) {
      entry.value.pause();
    }

    // Create sound object (real or mock)
    final sound =
        widget.video.sound ??
        Sound(
          id: 'original_${widget.video.user.id}',
          title: "Original Sound",
          author: widget.video.user.username ?? widget.video.user.name,
          url: "", // No separate audio URL for original sound
          coverUrl: widget.video.thumbnailUrl.isNotEmpty
              ? widget.video.thumbnailUrl
              : (widget.video.user.avatar ??
                    "https://www.shutterstock.com/image-vector/music-note-icon-vector-illustration-600nw-2253322131.jpg"),
          duration: 0,
        );

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => MusicDetailScreen(sound: sound),
          ),
        )
        .then((_) {
          // Resume if this is the current video (autoplay=true) and conditions are met
          final player = ref
              .read(mediaKitVideoProvider)
              .players[widget.video.id];
          if (widget.autoplay && player != null && !player.state.playing) {
            final bottomNav = ref.read(bottomNavIndexProvider);
            final audioEnabled = ref.read(isFeedAudioEnabledProvider);
            final currentTab = ref.read(activeFeedTabProvider);

            if ((widget.ignoreBottomNav || bottomNav == 0) &&
                audioEnabled &&
                (currentTab == 1 || currentTab == 2)) {
              player.play();
            }
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    // Listen to audio enabled changes - only pause when disabled
    ref.listen(isFeedAudioEnabledProvider, (previous, next) {
      if (!next) {
        _player?.pause();
      }
      // Note: Resume is handled by initial autoplay check below, not here
    });

    // Listen to bottom nav changes - pause when leaving feed
    ref.listen(bottomNavIndexProvider, (previous, next) {
      if (!widget.ignoreBottomNav && next != 0) {
        _player?.pause();
      } else if (widget.autoplay && next == 0 && previous != 0) {
        // Resume when returning to feed, but ONLY if this widget has autoplay=true
        final audioEnabled = ref.read(isFeedAudioEnabledProvider);
        final currentTab = ref.read(activeFeedTabProvider);

        if (audioEnabled &&
            (currentTab == 1 || currentTab == 2) &&
            _player != null &&
            !_player!.state.playing) {
          _player!.play();
        }
      }
      // Note: Resume is handled by initial autoplay check below, not here
    });

    // Listen to feed tab changes (For You, Following, Live)
    ref.listen(activeFeedTabProvider, (previous, next) {
      // Get the current video's tab from VideoFeedList's tabIndex
      // Note: We can't directly access widget.tabIndex from parent, but we can infer:
      // If this video is playing and tab changes, pause it
      if (_player != null &&
          _player!.state.playing &&
          previous != null &&
          previous != next) {
        _player!.pause();
      }

      // Resume when switching to this tab (only if autoplay=true for current video)
      if (widget.autoplay &&
          next != previous &&
          _player != null &&
          !_player!.state.playing) {
        final bottomNav = ref.read(bottomNavIndexProvider);
        final audioEnabled = ref.read(isFeedAudioEnabledProvider);

        if ((widget.ignoreBottomNav || bottomNav == 0) &&
            audioEnabled &&
            (next == 1 || next == 2)) {
          _player!.play();
        }
      }
    });

    // Autoplay logic: Only play if this widget has autoplay=true (which VideoFeedList
    // only sets for the current index) AND all other conditions are met
    if (widget.autoplay && _player != null && _controller != null) {
      final currentTab = ref.read(activeFeedTabProvider);
      final bottomNav = ref.read(bottomNavIndexProvider);
      final audioEnabled = ref.read(isFeedAudioEnabledProvider);

      final shouldPlay =
          (currentTab == 1 || currentTab == 2) &&
          (widget.ignoreBottomNav || bottomNav == 0) &&
          audioEnabled &&
          !_player!.state.playing;

      if (shouldPlay) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          // Small delay to ensure provider has finished pausing other players
          await Future.delayed(const Duration(milliseconds: 100));
          if (mounted && _player != null && !_player!.state.playing) {
            _player!.play();
            // Start view timer after video starts playing
            _startViewTimer();
          }
        });
      }
    }

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video player
          if (_controller != null)
            Center(
              child: _ZoomableContent(
                onTap: () {
                  if (_player != null) {
                    if (_player!.state.playing) {
                      _player!.pause();
                    } else {
                      _player!.play();
                    }
                  }
                },
                child: mk_video.Video(
                  controller: _controller!,
                  fit: BoxFit.cover,
                  controls: mk_video.NoVideoControls,
                ),
              ),
            ),

          // Top-Left: User Info
          Positioned(
            left: 10,
            top: 10,
            right: 80,
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  // Avatar
                  GestureDetector(
                    onTap: _navigateToProfile,
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white,
                      backgroundImage: widget.video.user.avatar != null
                          ? NetworkImage(widget.video.user.avatar!)
                          : null,
                      child: widget.video.user.avatar == null
                          ? Text(
                              widget.video.user.name[0].toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // User Name
                  Flexible(
                    child: GestureDetector(
                      onTap: _navigateToProfile,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "@${widget.video.user.username}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 4),
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
                                Shadow(color: Colors.black, blurRadius: 3),
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
                              color: AppColors.neonPink.withValues(alpha: 0.4),
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

          // Right Side Actions
          Positioned(
            bottom: 220,
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

          // Bottom-Left: Caption and Music
          Positioned(
            left: 10,
            right: 80,
            bottom: 100,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Caption
                  Text(
                    widget.video.caption,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      shadows: [Shadow(color: Colors.black, blurRadius: 3)],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),

                  // Music bar
                  GestureDetector(
                    onTap: _navigateToMusicDetail,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        // Music disc icon
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[800],
                            image: widget.video.sound?.coverUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(
                                      widget.video.sound!.coverUrl,
                                    ),
                                    fit: BoxFit.cover,
                                  )
                                : (widget.video.user.avatar != null
                                      ? DecorationImage(
                                          image: NetworkImage(
                                            widget.video.user.avatar!,
                                          ),
                                          fit: BoxFit.cover,
                                        )
                                      : null),
                          ),
                          child:
                              (widget.video.sound?.coverUrl == null &&
                                  widget.video.user.avatar == null)
                              ? const Icon(
                                  Icons.music_note,
                                  color: Colors.white,
                                  size: 16,
                                )
                              : null,
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
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// _ZoomableContent widget for zoom gestures
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

      endMatrix = Matrix4.identity()
        ..translate(center.dx, center.dy)
        ..scale(2.0)
        ..translate(-center.dx, -center.dy);

      widget.onInteractionStart?.call();
    } else {
      // Zoom Out to 1x
      endMatrix = Matrix4.identity();
      widget.onInteractionEnd?.call();
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
                    const SnackBar(content: Text('Report submitted.')),
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
        _updatePanEnablement();

        if (_pointers >= 2) {
          widget.onInteractionStart?.call();
          _longPressTimer?.cancel();
        }

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
        if (_longPressOrigin != null) {
          final distance = (event.position - _longPressOrigin!).distance;
          if (distance > 10.0) {
            _longPressTimer?.cancel();
          }
        }
      },
      onPointerUp: (event) {
        _pointers--;
        _updatePanEnablement();
        _longPressTimer?.cancel();
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
        transformationController: _transformationController,
        minScale: 1.0,
        maxScale: 4.0,
        panEnabled: _canPan,
        onInteractionStart: (details) {
          if (_pointers >= 2 || !_transformationController.value.isIdentity()) {
            widget.onInteractionStart?.call();
          }
        },
        onInteractionEnd: (details) {
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
