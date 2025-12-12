import 'package:flutter/material.dart';
import '../../features/feed/presentation/screens/feed_screen.dart';
import '../../features/camera/presentation/screens/video_recorder_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/chat/presentation/screens/chat_list_screen.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const FeedScreen(),
    const Center(child: Text("Discover")),
    const SizedBox.shrink(), // Placeholder for Record
    const ChatListScreen(),
    const ProfileScreen(userId: 1, isCurrentUser: true), // Mock current user
  ];

  void _onItemTapped(int index) {
    if (index == 2) {
      // Open Camera
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const VideoRecorderScreen()),
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [IndexedStack(index: _selectedIndex, children: _pages)],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
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
