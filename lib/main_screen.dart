import 'package:flutter/material.dart';
import 'package:test_flutter/features/feed/presentation/screens/feed_screen.dart';
import 'package:test_flutter/core/theme/app_theme.dart';
import 'package:test_flutter/core/widgets/glass_island_navigation.dart';
import 'package:test_flutter/features/camera/presentation/screens/video_recorder_screen.dart';
import 'package:test_flutter/features/profile/presentation/screens/profile_screen.dart';
import 'package:test_flutter/features/chat/presentation/screens/chat_list_screen.dart';
import 'package:test_flutter/features/discover/presentation/screens/discover_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/feed/presentation/providers/feed_audio_provider.dart';
import 'core/providers/navigation_provider.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final List<Widget> _pages = [
    const FeedScreen(),
    const DiscoverScreen(),
    const SizedBox.shrink(), // Placeholder for Record
    const ChatListScreen(),
    const ProfileScreen(userId: "1", isCurrentUser: true), // Mock current user
  ];

  void _onItemTapped(int index) async {
    final currentIndex = ref.read(bottomNavIndexProvider);

    if (index == 2) {
      // Pause feed by setting index to 2 (Camera)
      ref.read(bottomNavIndexProvider.notifier).state = index;

      // Open Camera
      final result = await Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const VideoRecorderScreen()),
      );

      if (result == 'live_mode') {
        // User went to Live Setup (which replaced Recorder).
        // Keep Feed Audio MUTED.
        ref.read(isFeedAudioEnabledProvider.notifier).state = false;
        // But restore index to 0 so we are "back home" visually behind the live screen
        ref.read(bottomNavIndexProvider.notifier).state = currentIndex;
      } else {
        // Standard return (Back button from Recorder)
        // Restore previous tab
        ref.read(bottomNavIndexProvider.notifier).state = currentIndex;
      }
    } else {
      if (index == 0 && currentIndex == 0) {
        // Already on home, tapping home again -> Reset to For You
        ref.read(feedTabResetProvider.notifier).state++;
      }
      ref.read(bottomNavIndexProvider.notifier).state = index;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(bottomNavIndexProvider);

    return Scaffold(
      backgroundColor: AppColors.deepVoid,
      body: Stack(
        children: [
          IndexedStack(index: selectedIndex, children: _pages),
          GlassIslandNavigation(
            selectedIndex: selectedIndex,
            onTap: _onItemTapped,
          ),
        ],
      ),
      // bottomNavigationBar Removed
    );
  }
}
