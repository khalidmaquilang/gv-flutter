import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/feed_provider.dart';
import '../widgets/video_feed_list.dart';
import '../widgets/live_feed_list.dart';
import '../../../../core/providers/navigation_provider.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: 2,
    ); // Start at "For You"
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(feedTabResetProvider, (previous, next) {
      if (next > 0) {
        _tabController.animateTo(2); // Reset to "For You"
        ref.refresh(feedProvider.future);
      }
    });

    final feedAsync = ref.watch(feedProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Content
          TabBarView(
            controller: _tabController,
            children: [
              // Live Tab
              const LiveFeedList(),

              // Following Tab (Reuse VideoFeedList)
              VideoFeedList(
                videos: feedAsync.value ?? [],
                isLoading: feedAsync.isLoading,
                error: feedAsync.error?.toString(),
                onRefresh: () async => ref.refresh(feedProvider.future),
                onLoadMore: () =>
                    ref.read(feedProvider.notifier).loadNextPage(),
              ),

              // For You Tab (Reuse VideoFeedList)
              VideoFeedList(
                videos: feedAsync.value ?? [],
                isLoading: feedAsync.isLoading,
                error: feedAsync.error?.toString(),
                onRefresh: () async => ref.refresh(feedProvider.future),
                onLoadMore: () =>
                    ref.read(feedProvider.notifier).loadNextPage(),
              ),
            ],
          ),

          // Top Gradient Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120, // Height of the gradient fade
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                ),
              ),
            ),
          ),

          // Top Navigation
          SafeArea(
            child: Container(
              padding: const EdgeInsets.only(top: 10),
              alignment: Alignment.topCenter,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicator: const UnderlineTabIndicator(
                  borderSide: BorderSide(width: 2.0, color: Colors.white),
                  insets: EdgeInsets.symmetric(horizontal: 10.0),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: "Live"),
                  Tab(text: "Following"),
                  Tab(text: "For You"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
