import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

import '../../../auth/data/models/user_model.dart';
import 'package:test_flutter/core/theme/app_theme.dart';
import '../../data/services/profile_service.dart';
import '../../../wallet/presentation/screens/wallet_screen.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../../core/widgets/neon_border_container.dart';
import 'package:test_flutter/core/providers/navigation_provider.dart'; // Add navigation provider import

import 'edit_profile_screen.dart';
import 'package:test_flutter/features/feed/presentation/providers/drafts_provider.dart';
import '../../data/models/profile_video_model.dart'; // Import Model
import '../../../../features/feed/presentation/screens/drafts_screen.dart';
import 'profile_feed_screen.dart';

final profileServiceProvider = Provider((ref) => ProfileService());

// State for pagination
class ProfileVideosState {
  final List<ProfileVideo> videos;
  final int page;
  final bool isLoading;
  final bool hasMore;

  ProfileVideosState({
    required this.videos,
    required this.page,
    required this.isLoading,
    required this.hasMore,
  });

  factory ProfileVideosState.initial() {
    return ProfileVideosState(
      videos: [],
      page: 1,
      isLoading: false,
      hasMore: true,
    );
  }

  // Combined list for UI
  List<ProfileVideo> get allVideos => videos;

  ProfileVideosState copyWith({
    List<ProfileVideo>? videos,
    int? page,
    bool? isLoading,
    bool? hasMore,
  }) {
    return ProfileVideosState(
      videos: videos ?? this.videos,
      page: page ?? this.page,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class ProfileVideosNotifier extends StateNotifier<ProfileVideosState> {
  final ProfileService _service;

  ProfileVideosNotifier(this._service) : super(ProfileVideosState.initial()) {
    loadVideos();
  }

  Future<void> loadVideos() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);

    try {
      final newVideos = await _service.getMyVideos(page: state.page);

      if (newVideos.isEmpty) {
        state = state.copyWith(isLoading: false, hasMore: false);
      } else {
        state = state.copyWith(
          videos: [...state.videos, ...newVideos],
          page: state.page + 1,
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refresh() async {
    // Keep processing videos, or clear them?
    // If upload is done, they should come from API.
    // Let's assume refresh means "sync with server", so clear processing.

    state = ProfileVideosState.initial().copyWith(isLoading: true);

    try {
      final newVideos = await _service.getMyVideos(page: 1);
      state = state.copyWith(
        videos: newVideos,
        page: 2,
        isLoading: false,
        hasMore: newVideos.isNotEmpty,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }
}

final profileVideosProvider =
    StateNotifierProvider.autoDispose<
      ProfileVideosNotifier,
      ProfileVideosState
    >((ref) {
      final service = ref.watch(profileServiceProvider);
      return ProfileVideosNotifier(service);
    });

@override
// ... existing providers ...
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

class ProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  final bool isCurrentUser;

  const ProfileScreen({
    super.key,
    required this.userId,
    this.isCurrentUser = false,
  });

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() => ref.read(profileVideosProvider.notifier).refresh());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(profileVideosProvider.notifier).loadVideos();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCurrentUser) {
      ref.listen(bottomNavIndexProvider, (previous, next) {
        if (next == 4) {
          ref.read(profileVideosProvider.notifier).refresh();
        }
      });
    }

    final AsyncValue<User> userAsync;
    if (widget.isCurrentUser) {
      final authState = ref.watch(authControllerProvider);
      userAsync = authState.when(
        data: (user) =>
            user != null ? AsyncValue.data(user) : const AsyncValue.loading(),
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    } else {
      userAsync = ref.watch(userProfileProvider(widget.userId));
    }
    final statsAsync = ref.watch(userStatsProvider(widget.userId));
    final draftsAsync = ref.watch(draftsProvider);
    final hasDrafts = draftsAsync.valueOrNull?.isNotEmpty ?? false;
    final draftsCount = draftsAsync.valueOrNull?.length ?? 0;

    final videosState = ref.watch(profileVideosProvider);
    final videos = videosState.allVideos;

    // Logic for grid items
    final gridItemCount = (hasDrafts ? 1 : 0) + videos.length;

    return Scaffold(
      backgroundColor: AppColors.deepVoid,
      body: SafeArea(
        child: Column(
          children: [
            // ... (keep existing header) ...
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                // ... existing header content ...
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  userAsync.when(
                    data: (user) => Text(
                      user.name,
                      // ...
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
                          if (widget.isCurrentUser) {
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
                controller: _scrollController,
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
                          color: Colors.white.withValues(alpha: 0.7),
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
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          _buildStat("Followers", stats['followers'] ?? 0),
                          Container(
                            height: 30,
                            width: 1,
                            color: Colors.white.withValues(alpha: 0.2),
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
                        if (widget.isCurrentUser)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
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
                                  color: AppColors.neonPink.withValues(
                                    alpha: 0.4,
                                  ),
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
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
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
                    if (videosState.isLoading && videos.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (videos.isEmpty && !hasDrafts)
                      const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Center(
                          child: Text(
                            "No videos yet",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
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
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount:
                            gridItemCount + (videosState.isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= gridItemCount) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (hasDrafts && index == 0) {
                            // Drafts Folder
                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const DraftsScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[850],
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(
                                      Icons.folder_open,
                                      size: 40,
                                      color: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 8,
                                      child: Text(
                                        "Drafts: $draftsCount",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          // Calculate video index
                          final videoIndex = hasDrafts ? index - 1 : index;
                          final video = videos[videoIndex];

                          return GestureDetector(
                            onTap: () {
                              userAsync.whenData((user) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProfileFeedScreen(
                                      videos: videos,
                                      initialIndex: videoIndex,
                                      user: user,
                                    ),
                                  ),
                                );
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                                image: DecorationImage(
                                  image: video.isProcessing
                                      ? FileImage(File(video.videoPath))
                                      : NetworkImage(video.thumbnail)
                                            as ImageProvider,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Stack(
                                      children: [
                                        // Processing Overlay
                                        if (video.isProcessing)
                                          Container(
                                            color: Colors.black.withValues(
                                              alpha: 0.5,
                                            ),
                                            child: const Center(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: AppColors.neonPink,
                                                  ),
                                                  SizedBox(height: 4),
                                                  Text(
                                                    "Processing",
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),

                                        // Play count (Hide if processing)
                                        if (!video.isProcessing)
                                          Positioned(
                                            bottom: 4,
                                            left: 4,
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.play_arrow_outlined,
                                                  color: Colors.white,
                                                  size: 14,
                                                ),
                                                Text(
                                                  "${video.views}",
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
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
