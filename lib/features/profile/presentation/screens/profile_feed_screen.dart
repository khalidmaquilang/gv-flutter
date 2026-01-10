import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:test_flutter/features/auth/data/models/user_model.dart';
import 'package:test_flutter/features/feed/presentation/widgets/media_kit_video_player_item.dart';
import 'package:test_flutter/features/feed/presentation/providers/media_kit_video_provider.dart';
import 'package:test_flutter/features/feed/data/models/video_model.dart';
import '../../data/models/profile_video_model.dart';

class ProfileFeedScreen extends ConsumerStatefulWidget {
  final List<ProfileVideo> videos;
  final int initialIndex;
  final User user;

  const ProfileFeedScreen({
    super.key,
    required this.videos,
    required this.initialIndex,
    required this.user,
  });

  @override
  ConsumerState<ProfileFeedScreen> createState() => _ProfileFeedScreenState();
}

class _ProfileFeedScreenState extends ConsumerState<ProfileFeedScreen> {
  late PageController _pageController;
  MediaKitVideoNotifier? _videoNotifier;

  int _currentIndex = 0;
  List<Video> _mappedVideos = [];
  Player? _currentPlayer; // Track current player for cleanup

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    // Convert ProfileVideos to standard Videos for the provider
    _mappedVideos = widget.videos.map((v) => v.toVideo(widget.user)).toList();

    // Init provider with current page and store notifier reference
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _videoNotifier = ref.read(mediaKitVideoProvider.notifier);
      _videoNotifier?.onPageChanged(_currentIndex, _mappedVideos);

      // Store the current player reference for cleanup
      if (_mappedVideos.isNotEmpty) {
        final videoId = _mappedVideos[_currentIndex].id;
        _currentPlayer = ref.read(mediaKitVideoProvider).players[videoId];
      }
    });
  }

  @override
  void dispose() {
    // Pause the current video using stored player reference
    if (_currentPlayer != null && _currentPlayer!.state.playing) {
      _currentPlayer!.pause();
    }
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: widget.videos.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });

              // Update current player reference when page changes
              if (index < _mappedVideos.length) {
                final videoId = _mappedVideos[index].id;
                _currentPlayer = ref
                    .read(mediaKitVideoProvider)
                    .players[videoId];
              }
              ref
                  .read(mediaKitVideoProvider.notifier)
                  .onPageChanged(index, _mappedVideos);
            },
            itemBuilder: (context, index) {
              final video = _mappedVideos[index];
              return MediaKitVideoPlayerItem(
                key: ValueKey(video.id),
                video: video,
                autoplay: index == _currentIndex,
                hideProfileInfo: true,
                ignoreBottomNav: true,
              );
            },
          ),

          // Back Button
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
