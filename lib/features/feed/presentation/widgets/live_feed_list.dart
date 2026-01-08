import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/live/data/services/live_service.dart';
import '../../../../features/live/data/models/live_stream_model.dart';
import '../../../../features/live/presentation/screens/live_stream_screen.dart';
import 'package:test_flutter/core/theme/app_theme.dart';

class LiveFeedList extends ConsumerStatefulWidget {
  const LiveFeedList({super.key});

  @override
  ConsumerState<LiveFeedList> createState() => _LiveFeedListState();
}

class _LiveFeedListState extends ConsumerState<LiveFeedList> {
  final _liveService = LiveService();
  List<LiveStream> _streams = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStreams();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadStreams() async {
    setState(() {
      _isLoading = true;
    });

    final allStreams = await _liveService.getActiveStreams();
    if (mounted) {
      // Filter to only show streams that have been started (currently broadcasting)
      final activeStreams = allStreams
          .where((stream) => stream.startedAt != null)
          .toList();

      setState(() {
        _streams = activeStreams;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_streams.isEmpty) {
      return const Center(
        child: Text("No active streams", style: TextStyle(color: Colors.white)),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 100), // Space for tabs
      child: RefreshIndicator(
        onRefresh: _loadStreams,
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // 2 columns
            childAspectRatio: 0.75, // Slightly taller than wide
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _streams.length,
          itemBuilder: (context, index) {
            final stream = _streams[index];
            return _buildLiveGridItem(stream);
          },
        ),
      ),
    );
  }

  Widget _buildLiveGridItem(LiveStream stream) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LiveStreamScreen(
              isBroadcaster: false,
              channelId: stream.channelId,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.deepVoid,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail/Background
              if (stream.user.avatar != null)
                Image.network(
                  stream.user.avatar!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(color: AppColors.deepVoid);
                  },
                )
              else
                Container(color: AppColors.deepVoid),

              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.deepVoid.withOpacity(0.8),
                    ],
                  ),
                ),
              ),

              // LIVE Badge
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.neonPink,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neonPink.withOpacity(0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Text(
                    "LIVE",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Viewers Count
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.remove_red_eye,
                        color: AppColors.neonCyan,
                        size: 10,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        "${stream.viewersCount}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // User Info at Bottom
              Positioned(
                bottom: 8,
                right: 8,
                left: 60, // Space for LIVE badge
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      stream.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black, blurRadius: 3)],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stream.user.username ?? stream.user.name,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
