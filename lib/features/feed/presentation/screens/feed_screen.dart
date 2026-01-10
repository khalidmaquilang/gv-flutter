import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/feed_provider.dart';
import '../widgets/video_feed_list.dart';
import '../widgets/live_feed_list.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../../../search/presentation/screens/search_screen.dart';
import '../providers/feed_audio_provider.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _feedKey = 0;
  int _liveKey = 0;
  int _lastTappedIndex = 2; // Track last tapped tab for refresh logic

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: 2,
    ); // Start at "For You"

    // Explicitly set the active tab to match initial index
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeFeedTabProvider.notifier).state = 2;
    });

    // Listen to tab changes to update activeFeedTabProvider
    _tabController.addListener(() {
      final newIndex = _tabController.index;
      if (newIndex != _lastTappedIndex) {
        _lastTappedIndex = newIndex;
        ref.read(activeFeedTabProvider.notifier).state = newIndex;
      }
    });
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

        // Refresh all three tabs
        // ignore: unused_result
        ref.refresh(followingFeedProvider.future);
        // ignore: unused_result
        ref.refresh(feedProvider.future);

        setState(() {
          _feedKey++;
          _liveKey++; // Force Live tab to rebuild and refresh
        });
      }
    });

    final feedAsync = ref.watch(feedProvider);
    final followingFeedAsync = ref.watch(followingFeedProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Content
          TabBarView(
            controller: _tabController,
            children: [
              // Live Tab
              LiveFeedList(key: ValueKey("live_$_liveKey")),

              // Following Tab
              VideoFeedList(
                videos: followingFeedAsync.value ?? [],
                isLoading: followingFeedAsync.isLoading,
                error: followingFeedAsync.error?.toString(),
                onRefresh: () async =>
                    ref.refresh(followingFeedProvider.future),
                onLoadMore: () =>
                    ref.read(followingFeedProvider.notifier).loadNextPage(),
                tabIndex: 1, // Following Tab Index
              ),

              // For You Tab
              VideoFeedList(
                key: ValueKey("feed_fy_$_feedKey"),
                videos: feedAsync.value ?? [],
                isLoading: feedAsync.isLoading,
                error: feedAsync.error?.toString(),
                onRefresh: () async => ref.refresh(feedProvider.future),
                onLoadMore: () =>
                    ref.read(feedProvider.notifier).loadNextPage(),
                tabIndex: 2, // For You Tab Index
              ),
            ],
          ),

          // Top Gradient Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120, // Height of the gradient fade
            child: IgnorePointer(
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
          ),

          // Top Navigation
          SafeArea(
            child: Container(
              padding: const EdgeInsets.only(
                top: 60,
              ), // Pushed down for User Profile
              alignment: Alignment.topCenter,
              child: TabBar(
                controller: _tabController,
                isScrollable: false,
                tabAlignment: TabAlignment.center,
                indicator: const UnderlineTabIndicator(
                  borderSide: BorderSide(width: 2.0, color: Colors.white),
                  insets: EdgeInsets.symmetric(horizontal: 10.0),
                ),
                overlayColor: WidgetStateProperty.all(
                  Colors.transparent,
                ), // Remove tap overlay
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

          // Search Icon (Top Right)
          Positioned(
            top: 0,
            right: 16,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 6,
                ), // Align with Profile (10px padding + 20px radius - 24px icon center = 6px)
                child: IconButton(
                  icon: const Icon(
                    Icons.search,
                    color: Colors.white,
                    size: 28,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SearchScreen(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
