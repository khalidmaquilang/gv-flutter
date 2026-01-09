import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../camera/data/models/sound_model.dart';
import '../providers/feed_provider.dart';
import '../../../search/presentation/widgets/video_search_result_item.dart';
import '../../../camera/presentation/screens/video_recorder_screen.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/video_model.dart';
// import '../widgets/video_player_item.dart'; // Unused
import 'dart:ui';

class MusicDetailScreen extends ConsumerStatefulWidget {
  final Sound sound;

  const MusicDetailScreen({super.key, required this.sound});

  @override
  ConsumerState<MusicDetailScreen> createState() => _MusicDetailScreenState();
}

class _MusicDetailScreenState extends ConsumerState<MusicDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  List<Video> _videos = [];
  bool _isLoading = true;
  String? _nextCursor;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadVideos();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadVideos() async {
    if (!_hasMore && _nextCursor == null) return;

    try {
      final service = ref.read(videoServiceProvider);
      final response = await service.getVideosByMusic(
        widget.sound.id,
        cursor: _nextCursor,
      );

      if (mounted) {
        setState(() {
          if (_nextCursor == null) {
            _videos = response.videos;
          } else {
            _videos.addAll(response.videos);
          }
          _nextCursor = response.nextCursor;
          _isLoading = false;
          _hasMore = response.nextCursor != null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print("Error loading music videos: $e");
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadVideos();
    }
  }

  void _useMusic() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoRecorderScreen(initialSound: widget.sound),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepVoid,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _useMusic,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonPink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 5,
              shadowColor: AppColors.neonPink.withOpacity(0.5),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam),
                SizedBox(width: 8),
                Text(
                  "Use this sound",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.deepVoid,
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Blurred Background
                  Image.network(widget.sound.coverUrl, fit: BoxFit.cover),
                  Container(
                    color: Colors.black.withOpacity(0.7),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                  // Content
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Album Art
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: NetworkImage(widget.sound.coverUrl),
                              fit: BoxFit.cover,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Text Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.sound.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.sound.author,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Grid
          if (_isLoading && _videos.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.neonPink),
              ),
            )
          else if (_videos.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  "No videos yet",
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 1.0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 3 / 4,
                  crossAxisSpacing: 1,
                  mainAxisSpacing: 1,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final video = _videos[index];
                  return VideoSearchResultItem(
                    thumbnailUrl: video.thumbnailUrl,
                    viewsCount: video
                        .formattedViews, // Add formatted views to video model if missing?
                    // Wait, Video model has formattedViews.
                    userAvatarUrl: video.user.avatar ?? "",
                    username: video.user.username ?? video.user.name,
                  );
                }, childCount: _videos.length),
              ),
            ),

          // Loading More Indicator
          if (_hasMore && !_isLoading && _videos.isNotEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.neonPink),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
