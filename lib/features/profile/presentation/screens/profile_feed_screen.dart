import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test_flutter/features/auth/data/models/user_model.dart';
import 'package:test_flutter/features/feed/presentation/widgets/video_player_item.dart';
import 'package:test_flutter/features/feed/presentation/providers/video_preload_provider.dart';
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
  VideoPreloadNotifier? _videoNotifier;

  int _currentIndex = 0;
  List<Video> _mappedVideos = [];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    // Convert ProfileVideos to standard Videos for the provider
    _mappedVideos = widget.videos.map((v) => v.toVideo(widget.user)).toList();

    // Init provider with current page and store notifier reference
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _videoNotifier = ref.read(videoPreloadProvider.notifier);
      _videoNotifier?.onPageChanged(_currentIndex, _mappedVideos);
    });
  }

  @override
  void dispose() {
    // Pause the current video before disposing using stored reference
    _videoNotifier?.pauseCurrentVideo();
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
              ref
                  .read(videoPreloadProvider.notifier)
                  .onPageChanged(index, _mappedVideos);
            },
            itemBuilder: (context, index) {
              final video = _mappedVideos[index];
              return VideoPlayerItem(
                key: ValueKey(video.id),
                video: video,
                autoplay: index == _currentIndex,
                ignoreBottomNav: true,
              );
            },
          ),

          // Back Button
          Positioned(
            top: 40,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
