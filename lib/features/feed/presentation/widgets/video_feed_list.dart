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
  });

  @override
  State<VideoFeedList> createState() => _VideoFeedListState();
}

class _VideoFeedListState extends State<VideoFeedList> {
  bool _isScrollEnabled = true;

  void _onInteractionStart() {
    setState(() {
      _isScrollEnabled = false;
    });
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
        child: Text(
          "No videos found",
          style: const TextStyle(color: Colors.white),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh ?? () async {},
      child: PageView.builder(
        scrollDirection: Axis.vertical,
        physics: _isScrollEnabled
            ? const AlwaysScrollableScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        itemCount: widget.videos.length,
        itemBuilder: (context, index) {
          return VideoPlayerItem(
            video: widget.videos[index],
            onInteractionStart: _onInteractionStart,
            onInteractionEnd: _onInteractionEnd,
          );
        },
      ),
    );
  }
}
