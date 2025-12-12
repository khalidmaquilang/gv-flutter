import 'package:flutter/material.dart';
import '../../data/models/video_model.dart';
import 'video_player_item.dart';

class VideoFeedList extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Text(
          "Error: $error",
          style: const TextStyle(color: Colors.white),
        ),
      );
    }

    if (videos.isEmpty) {
      return const Center(
        child: Text(
          "No videos found",
          style: const TextStyle(color: Colors.white),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      child: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: videos.length,
        itemBuilder: (context, index) {
          return VideoPlayerItem(video: videos[index]);
        },
      ),
    );
  }
}
