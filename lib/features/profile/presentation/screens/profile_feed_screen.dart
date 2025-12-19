import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test_flutter/features/auth/data/models/user_model.dart';
import 'package:test_flutter/features/feed/presentation/widgets/video_player_item.dart';
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

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
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
            },
            itemBuilder: (context, index) {
              final video = widget.videos[index].toVideo(widget.user);
              return VideoPlayerItem(
                key: ValueKey(video.id),
                video: video,
                autoplay: index == _currentIndex,
                shouldPrepare:
                    (index - _currentIndex).abs() <=
                    1, // Relaxed: Keep current, prev, and next prepared.
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
