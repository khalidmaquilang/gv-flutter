import 'package:flutter/material.dart';
import 'package:test_flutter/features/feed/presentation/screens/feed_screen.dart';
import 'package:test_flutter/features/camera/presentation/screens/video_recorder_screen.dart';
import 'package:test_flutter/features/profile/presentation/screens/profile_screen.dart';
import 'package:test_flutter/features/chat/presentation/screens/chat_list_screen.dart';
import 'package:test_flutter/features/discover/presentation/screens/discover_screen.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/navigation_provider.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  // We use the provider for state execution, but local state for the indexed stack rendering is tied to the provider?
  // Actually simpler: Just watch the provider for index.

  final List<Widget> _pages = [
    const FeedScreen(),
    const DiscoverScreen(),
    const SizedBox.shrink(), // Placeholder for Record
    const ChatListScreen(),
    const ProfileScreen(userId: 1, isCurrentUser: true), // Mock current user
  ];

  void _onItemTapped(int index) async {
    if (index == 2) {
      // Pause feed by setting index to 2 (Camera)
      final previousIndex = ref.read(bottomNavIndexProvider);
      ref.read(bottomNavIndexProvider.notifier).state = index;

      // Open Camera
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const VideoRecorderScreen()),
      );

      // Restore previous tab upon return
      ref.read(bottomNavIndexProvider.notifier).state = previousIndex;
    } else {
      ref.read(bottomNavIndexProvider.notifier).state = index;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(bottomNavIndexProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [IndexedStack(index: selectedIndex, children: _pages)],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        currentIndex: selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Discover'),
          BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.plus, size: 30), // Plus Button
            label: '',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Inbox'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
