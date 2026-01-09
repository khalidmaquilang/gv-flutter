import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/user_search_result_item.dart';
import '../widgets/video_search_result_item.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  // Mock Data for "Users"
  final List<Map<String, dynamic>> _mockUsers = [
    {
      "name": "Sarah Jenkins",
      "username": "sarah.j_art",
      "avatar": "https://i.pravatar.cc/150?u=sarah",
      "followers": "1.2M",
      "isFollowing": true,
    },
    {
      "name": "David Miller",
      "username": "david_vlogs",
      "avatar": "https://i.pravatar.cc/150?u=david",
      "followers": "450K",
      "isFollowing": false,
    },
    {
      "name": "Tech Reviewer",
      "username": "tech_guru",
      "avatar": "https://i.pravatar.cc/150?u=tech",
      "followers": "2.8M",
      "isFollowing": false,
    },
    {
      "name": "Cooking 101",
      "username": "chef_mario",
      "avatar": "https://i.pravatar.cc/150?u=chef",
      "followers": "89K",
      "isFollowing": true,
    },
  ];

  // Mock Data for "Videos"
  final List<Map<String, dynamic>> _mockVideos = List.generate(
    10,
    (index) => {
      "thumbnail": "https://picsum.photos/seed/$index/300/500",
      "views": "${(index + 1) * 15}K",
      "avatar": "https://i.pravatar.cc/150?u=$index",
      "username": "user_$index",
    },
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.deepVoid,
        appBar: AppBar(
          backgroundColor: AppColors.deepVoid,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: AppColors.textMain),
            onPressed: () => Navigator.pop(context),
          ),
          title: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(4),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppColors.textMain),
              decoration: const InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(color: Colors.grey),
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          bottom: const TabBar(
            indicatorColor: AppColors.neonPink,
            labelColor: AppColors.textMain,
            unselectedLabelColor: Colors.grey,
            labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              Tab(text: "Top"),
              Tab(text: "Users"),
              Tab(text: "Videos"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TOP TAB: Mix of users and videos
            _buildTopTab(),

            // USERS TAB
            ListView.builder(
              padding: const EdgeInsets.only(top: 8),
              itemCount: _mockUsers.length,
              itemBuilder: (context, index) {
                final user = _mockUsers[index];
                return UserSearchResultItem(
                  name: user['name'],
                  username: user['username'],
                  avatarUrl: user['avatar'],
                  followersCount: user['followers'],
                  isFollowing: user['isFollowing'],
                );
              },
            ),

            // VIDEOS TAB
            GridView.builder(
              padding: const EdgeInsets.all(2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7, // Portrait Aspect Ratio
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: _mockVideos.length,
              itemBuilder: (context, index) {
                final video = _mockVideos[index];
                return VideoSearchResultItem(
                  thumbnailUrl: video['thumbnail'],
                  viewsCount: video['views'],
                  userAvatarUrl: video['avatar'],
                  username: video['username'],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Users",
            style: TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          // Show first 2 users
          ..._mockUsers
              .take(2)
              .map(
                (user) => UserSearchResultItem(
                  name: user['name'],
                  username: user['username'],
                  avatarUrl: user['avatar'],
                  followersCount: user['followers'],
                  isFollowing: user['isFollowing'],
                ),
              ),

          const SizedBox(height: 24),
          const Text(
            "Videos",
            style: TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          // Show a grid of first 4 videos without scrolling (using shrinkWrap)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: 4,
            itemBuilder: (context, index) {
              final video = _mockVideos[index];
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: VideoSearchResultItem(
                  thumbnailUrl: video['thumbnail'],
                  viewsCount: video['views'],
                  userAvatarUrl: video['avatar'],
                  username: video['username'],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
