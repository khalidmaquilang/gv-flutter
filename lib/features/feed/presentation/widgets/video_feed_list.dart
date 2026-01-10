import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:preload_page_view/preload_page_view.dart'; // PreloadPageView
import '../../data/models/video_model.dart';
import '../providers/media_kit_video_provider.dart'; // MediaKit provider
import 'media_kit_video_player_item.dart';
import 'live_preview_item.dart';
import '../providers/feed_audio_provider.dart';

class VideoFeedList extends ConsumerStatefulWidget {
  final List<Video> videos;
  final bool isLoading;
  final String? error;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onLoadMore;
  final int tabIndex; // Index of the tab this list belongs to

  const VideoFeedList({
    super.key,
    required this.videos,
    this.isLoading = false,
    this.error,
    this.onRefresh,
    this.onLoadMore,
    required this.tabIndex,
  });

  @override
  ConsumerState<VideoFeedList> createState() => _VideoFeedListState();
}

class _VideoFeedListState extends ConsumerState<VideoFeedList>
    with AutomaticKeepAliveClientMixin {
  bool _isScrollEnabled = true;
  int _currentIndex = 0;
  late PreloadPageController
  _pageController; // Changed to PreloadPageController

  @override
  bool get wantKeepAlive => true; // Keep state when switching tabs

  @override
  void initState() {
    super.initState();
    _pageController = PreloadPageController(
      initialPage: _currentIndex,
      keepPage: true, // Preserve page position
    );

    // Initialize media_kit preload for first video
    if (widget.videos.isNotEmpty) {
      debugPrint(
        'VideoFeedList.initState: Scheduling media_kit initialization',
      );
      debugPrint('  videos.length: ${widget.videos.length}');
      // Use Future.microtask to initialize BEFORE PageView builds
      Future.microtask(() {
        debugPrint('VideoFeedList: Microtask executing');
        ref
            .read(mediaKitVideoProvider.notifier)
            .onPageChanged(0, widget.videos);
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onInteractionStart() {
    setState(() {
      _isScrollEnabled = false;
    });
  }

  @override
  void didUpdateWidget(VideoFeedList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Initialize media_kit when videos first become available
    if (widget.videos.isNotEmpty && oldWidget.videos.isEmpty) {
      debugPrint('VideoFeedList: Videos just loaded, initializing media_kit');
      debugPrint('  videos.length: ${widget.videos.length}');
      // Use Future.microtask for immediate initialization
      Future.microtask(() {
        ref
            .read(mediaKitVideoProvider.notifier)
            .onPageChanged(0, widget.videos);
      });
    }

    if (widget.videos.isNotEmpty &&
        oldWidget.videos.isNotEmpty &&
        widget.videos[0].id != oldWidget.videos[0].id) {
      // Feed changed (probably refreshed) - reset to first video
      _currentIndex = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  void _onInteractionEnd() {
    setState(() {
      _isScrollEnabled = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // Watch the active tab index
    final activeTab = ref.watch(activeFeedTabProvider);
    final isTabActive = activeTab == widget.tabIndex;

    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.error != null) {
      return Center(
        child: Text(
          "Error: ${widget.error}",
          style: const TextStyle(color: Colors.white),
        ),
      );
    }

    if (widget.videos.isEmpty) {
      return const Center(
        child: Text("No videos found", style: TextStyle(color: Colors.white)),
      );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh ?? () async {},
      child: PreloadPageView.builder(
        // Changed to PreloadPageView
        controller: _pageController,
        scrollDirection: Axis.vertical,
        preloadPagesCount:
            1, // Preload 1 page before and after (built-in feature!)
        physics: _isScrollEnabled
            ? const AlwaysScrollableScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        itemCount: widget.videos.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });

          // Only preload if it's a regular video, not a live stream
          if (!widget.videos[index].isLiveStream) {
            ref
                .read(mediaKitVideoProvider.notifier) // Use media_kit provider
                .onPageChanged(index, widget.videos);
          }

          // Trigger load more when within 2 items of end
          if (widget.onLoadMore != null && index >= widget.videos.length - 2) {
            widget.onLoadMore!();
          }
        },
        itemBuilder: (context, index) {
          final video = widget.videos[index];

          // Show LivePreviewItem for live streams, VideoPlayerItem for regular videos
          if (video.isLiveStream) {
            return LivePreviewItem(
              video: video,
              onInteractionStart: _onInteractionStart,
              onInteractionEnd: _onInteractionEnd,
            );
          } else {
            return MediaKitVideoPlayerItem(
              video: video,
              onInteractionStart: _onInteractionStart,
              onInteractionEnd: _onInteractionEnd,
              // Only autoplay if this list's tab is active AND it's the current item
              autoplay: isTabActive && (index == _currentIndex),
            );
          }
        },
      ),
    );
  }
}
