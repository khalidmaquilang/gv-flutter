import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/models/user_model.dart';
import 'package:test_flutter/core/theme/app_theme.dart';
import '../../data/services/profile_service.dart';
import '../../../wallet/presentation/screens/wallet_screen.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../../core/widgets/neon_border_container.dart';
import 'edit_profile_screen.dart';

final profileServiceProvider = Provider((ref) => ProfileService());

final userProfileProvider = FutureProvider.family<User, String>((
  ref,
  userId,
) async {
  return ref.read(profileServiceProvider).getProfile(userId);
});

final userStatsProvider = FutureProvider.family<Map<String, int>, String>((
  ref,
  userId,
) async {
  return ref.read(profileServiceProvider).getStats(userId);
});

class ProfileScreen extends ConsumerWidget {
  final String userId;
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
      backgroundColor: AppColors.deepVoid,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  userAsync.when(
                    data: (user) => Text(
                      user.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(color: AppColors.neonPink, blurRadius: 10),
                        ],
                      ),
                    ),
                    loading: () => const Text(
                      "Loading...",
                      style: TextStyle(color: Colors.white),
                    ),
                    error: (_, __) => const Text(
                      "Profile",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.account_balance_wallet,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const WalletScreen(),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white),
                        onPressed: () async {
                          if (isCurrentUser) {
                            await ref
                                .read(authControllerProvider.notifier)
                                .logout();
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
                      IconButton(
                        icon: const Icon(Icons.menu, color: Colors.white),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // Avatar
                    userAsync.when(
                      data: (user) => NeonBorderContainer(
                        shape: BoxShape.circle,
                        borderWidth: 3,
                        padding: const EdgeInsets.all(4),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundImage: NetworkImage(user.avatar ?? ""),
                        ),
                      ),
                      loading: () => const CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey,
                      ),
                      error: (_, __) => const CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Username
                    userAsync.when(
                      data: (user) => Text(
                        "@${user.name.replaceAll(' ', '').toLowerCase()}",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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
                          Container(
                            height: 30,
                            width: 1,
                            color: Colors.white.withOpacity(0.2),
                          ),
                          _buildStat("Followers", stats['followers'] ?? 0),
                          Container(
                            height: 30,
                            width: 1,
                            color: Colors.white.withOpacity(0.2),
                          ),
                          _buildStat("Likes", stats['likes'] ?? 0),
                        ],
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (_, __) => const Text("Failed to load stats"),
                    ),
                    const SizedBox(height: 24),
                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isCurrentUser)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: MaterialButton(
                              onPressed: () {
                                userAsync.whenData((user) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EditProfileScreen(
                                        user: {
                                          'name': user.name,
                                          'avatar': user.avatar,
                                          'bio': user.bio,
                                        },
                                      ),
                                    ),
                                  );
                                });
                              },
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 12,
                              ),
                              child: const Text(
                                "Edit Profile",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.neonPink.withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: MaterialButton(
                              onPressed: () {}, // Todo: Follow
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 12,
                              ),
                              child: const Text(
                                "Follow",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                            ),
                            onPressed: () {},
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    // Mock Grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.8,
                            crossAxisSpacing: 1,
                            mainAxisSpacing: 1,
                          ),
                      itemCount: 9,
                      itemBuilder: (context, index) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            border: Border.all(
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.play_arrow,
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
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
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
