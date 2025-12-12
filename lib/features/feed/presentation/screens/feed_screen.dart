import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/feed_provider.dart';
import '../widgets/video_feed_list.dart';
import '../widgets/live_feed_list.dart';

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
              ),

              // For You Tab (Reuse VideoFeedList)
              VideoFeedList(
                videos: feedAsync.value ?? [],
                isLoading: feedAsync.isLoading,
                error: feedAsync.error?.toString(),
              ),
            ],
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
