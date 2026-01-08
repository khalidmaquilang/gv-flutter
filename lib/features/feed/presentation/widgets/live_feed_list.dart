import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';
import '../../../../features/live/data/services/live_service.dart';
import '../../../../features/live/data/models/live_stream_model.dart';
import '../../../../features/live/presentation/screens/live_stream_screen.dart';
import 'package:test_flutter/core/theme/app_theme.dart';
import 'package:test_flutter/core/constants/api_constants.dart';

class LiveFeedList extends ConsumerStatefulWidget {
  const LiveFeedList({super.key});

  @override
  ConsumerState<LiveFeedList> createState() => _LiveFeedListState();
}

class _LiveFeedListState extends ConsumerState<LiveFeedList> {
  final _liveService = LiveService();
  final _liveListController = ZegoLiveStreamingOutsideLiveListController();
  List<LiveStream> _streams = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStreams();
  }

  @override
  void dispose() {
    _liveListController.dispose();
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

      // Update ZegoCloud live list with hosts
      if (_streams.isNotEmpty) {
        _liveListController.updateHosts(
          _streams.map((stream) {
            return ZegoLiveStreamingOutsideLiveListHost(
              roomID: stream.channelId, // Using stream_key as roomID
              user: ZegoUIKitUser(id: stream.user.id, name: stream.user.name),
            );
          }).toList(),
        );
      } else {
        _liveListController.updateHosts([]);
      }
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

    return RefreshIndicator(
      onRefresh: _loadStreams,
      child: ZegoLiveStreamingOutsideLiveList(
        appID: ApiConstants.zegoAppId,
        appSign: ApiConstants.zegoAppSign,
        controller: _liveListController,
        style: ZegoLiveStreamingOutsideLiveListStyle(
          padding: const EdgeInsets.all(8),
          item: ZegoLiveStreamingOutsideLiveListItemStyle(
            size: const Size(double.infinity, 240),
            borderRadius: 12,
            foregroundBuilder: _buildLiveItemForeground,
          ),
        ),
      ),
    );
  }

  Widget _buildLiveItemForeground(
    BuildContext context,
    Size size,
    ZegoUIKitUser? user,
    String roomID,
  ) {
    // Find the corresponding stream data
    final stream = _streams.firstWhere(
      (s) => s.channelId == roomID,
      orElse: () => _streams.first,
    );

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                LiveStreamScreen(isBroadcaster: false, channelId: roomID),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, AppColors.deepVoid.withOpacity(0.8)],
          ),
        ),
        child: Stack(
          children: [
            // Live Badge
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.neonPink,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neonPink.withOpacity(0.6),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Text(
                  "LIVE",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.remove_red_eye,
                      color: AppColors.neonCyan,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${stream.viewersCount}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
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
              left: 8,
              right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    stream.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(1),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.primaryGradient,
                        ),
                        child: CircleAvatar(
                          radius: 10,
                          backgroundImage: stream.user.avatar != null
                              ? NetworkImage(stream.user.avatar!)
                              : null,
                          backgroundColor: AppColors.deepVoid,
                          child: stream.user.avatar == null
                              ? Text(
                                  stream.user.name[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          stream.user.username ?? stream.user.name,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
