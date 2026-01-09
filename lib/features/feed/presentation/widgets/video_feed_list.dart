import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/video_model.dart';
import '../providers/video_preload_provider.dart';
import 'video_player_item.dart';
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
  late PageController _pageController;

  @override
  bool get wantKeepAlive => true; // Keep state when switching tabs

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: _currentIndex,
      keepPage: true, // Preserve page position
    );

    // Initialize preload for first video
    if (widget.videos.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Call onPageChanged which will skip live streams automatically
        ref.read(videoPreloadProvider.notifier).onPageChanged(0, widget.videos);
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
      child: PageView.builder(
        controller: _pageController, // Attach controller
        allowImplicitScrolling: true,
        scrollDirection: Axis.vertical,
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
                .read(videoPreloadProvider.notifier)
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
            return VideoPlayerItem(
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
