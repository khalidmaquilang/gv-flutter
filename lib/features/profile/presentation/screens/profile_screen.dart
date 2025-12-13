import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/models/user_model.dart';
import '../../data/services/profile_service.dart';
import '../../../wallet/presentation/screens/wallet_screen.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/screens/login_screen.dart';

final profileServiceProvider = Provider((ref) => ProfileService());

final userProfileProvider = FutureProvider.family<User, int>((
  ref,
  userId,
) async {
  return ref.read(profileServiceProvider).getProfile(userId);
});

final userStatsProvider = FutureProvider.family<Map<String, int>, int>((
  ref,
  userId,
) async {
  return ref.read(profileServiceProvider).getStats(userId);
});

class ProfileScreen extends ConsumerWidget {
  final int userId;
  final bool isCurrentUser;

  const ProfileScreen({
    super.key,
    required this.userId,
    this.isCurrentUser = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider(userId));
    final statsAsync = ref.watch(userStatsProvider(userId));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: userAsync.when(
          data: (user) => Text(user.name),
          loading: () => const Text("Loading..."),
          error: (_, __) => const Text("Profile"),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const WalletScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              if (isCurrentUser) {
                await ref.read(authControllerProvider.notifier).logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                    (route) => false,
                  );
                }
              }
            },
          ),
          IconButton(icon: const Icon(Icons.menu), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Avatar
            userAsync.when(
              data: (user) => CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(user.avatar ?? ""),
              ),
              loading: () =>
                  const CircleAvatar(radius: 50, backgroundColor: Colors.grey),
              error: (_, __) =>
                  const CircleAvatar(radius: 50, backgroundColor: Colors.red),
            ),
            const SizedBox(height: 12),
            // Username
            userAsync.when(
              data: (user) => Text(
                "@${user.name.replaceAll(' ', '').toLowerCase()}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
            const SizedBox(height: 20),
            // Stats
            statsAsync.when(
              data: (stats) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStat("Following", stats['following'] ?? 0),
                  _buildStat("Followers", stats['followers'] ?? 0),
                  _buildStat("Likes", stats['likes'] ?? 0),
                ],
              ),
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text("Failed to load stats"),
            ),
            const SizedBox(height: 20),
            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isCurrentUser)
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text("Edit Profile"),
                  )
                else
                  ElevatedButton(
                    onPressed: () {}, // Todo: Follow
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD900EE),
                    ),
                    child: const Text(
                      "Follow",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {},
                  child: const Icon(Icons.camera_alt, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Mock Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.7,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: 9,
              itemBuilder: (context, index) {
                return Container(
                  color: Colors.grey[800],
                  child: const Center(
                    child: Icon(Icons.play_arrow, color: Colors.white),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Text(
            "$count",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
