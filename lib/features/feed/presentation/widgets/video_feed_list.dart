import 'package:flutter/material.dart';
import '../../data/models/video_model.dart';
import 'video_player_item.dart';

class VideoFeedList extends StatefulWidget {
  final List<Video> videos;
  final bool isLoading;
  final String? error;
  final Future<void> Function()? onRefresh;

  const VideoFeedList({
    super.key,
    required this.videos,
    this.isLoading = false,
    this.error,

    this.onRefresh,
    this.onLoadMore,
  });

  final VoidCallback? onLoadMore;

  @override
  State<VideoFeedList> createState() => _VideoFeedListState();
}

class _VideoFeedListState extends State<VideoFeedList> {
  bool _isScrollEnabled = true;
  int _currentIndex = 0;

  void _onInteractionStart() {
    setState(() {
      _isScrollEnabled = false;
    });
  }

  @override
  void didUpdateWidget(VideoFeedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the list was replaced and is short (suggests reload), or completely different logic
    // But simplest for now: If first video ID changes, we assume it's a new feed?
    // Or if previous list length > current list length?
    // Let's reset if the list completely changes.
    // Actually, if we are loading, we are unmounted.
    // But if we come back, we are new state?
    // If we are NOT unmounted, we need to reset.
    if (widget.videos.isNotEmpty &&
        oldWidget.videos.isNotEmpty &&
        widget.videos[0].id != oldWidget.videos[0].id) {
      // Feed changed (probably refreshed)
      _currentIndex = 0;
    }
  }

  void _onInteractionEnd() {
    setState(() {
      _isScrollEnabled = true;
    });
  }

  @override
  Widget build(BuildContext context) {
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
          // Trigger load more when within 2 items of end
          if (widget.onLoadMore != null && index >= widget.videos.length - 2) {
            widget.onLoadMore!();
          }
        },
        itemBuilder: (context, index) {
          return VideoPlayerItem(
            video: widget.videos[index],
            onInteractionStart: _onInteractionStart,
            onInteractionEnd: _onInteractionEnd,
            autoplay: index == _currentIndex,
            shouldPrepare: (index - _currentIndex).abs() <= 1,
          );
        },
      ),
    );
  }
}
