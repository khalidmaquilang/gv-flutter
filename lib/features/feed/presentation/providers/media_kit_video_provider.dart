import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as mk_video;
import '../../data/models/video_model.dart'
    as model; // Use prefix to avoid conflict

/// State class for managing media_kit players
class MediaKitVideoState {
  final Map<String, Player> players;
  final Map<String, mk_video.VideoController> controllers;

  MediaKitVideoState({this.players = const {}, this.controllers = const {}});

  MediaKitVideoState copyWith({
    Map<String, Player>? players,
    Map<String, mk_video.VideoController>? controllers,
  }) {
    return MediaKitVideoState(
      players: players ?? this.players,
      controllers: controllers ?? this.controllers,
    );
  }
}

/// Notifier for managing media_kit video players with preloading
class MediaKitVideoNotifier extends StateNotifier<MediaKitVideoState> {
  MediaKitVideoNotifier() : super(MediaKitVideoState());

  // Max number of simultaneous players (current, next, previous)
  static const int kMaxConcurrentPlayers = 3;

  Future<void> onPageChanged(int currentIndex, List<model.Video> videos) async {
    print('MediaKitVideoProvider.onPageChanged called:');
    print('  currentIndex: $currentIndex');
    print('  videos.length: ${videos.length}');

    final newPlayers = Map<String, Player>.from(state.players);
    final newControllers = Map<String, mk_video.VideoController>.from(
      state.controllers,
    );
    final idsToKeep = <String>{};

    // CRITICAL: Pause ALL existing players first to prevent overlapping audio
    for (final player in newPlayers.values) {
      if (player.state.playing) {
        await player.pause();
      }
    }

    // Determine videos to preload
    final indicesToLoad = <int>[];
    indicesToLoad.add(currentIndex); // Current video
    if (currentIndex + 1 < videos.length) {
      indicesToLoad.add(currentIndex + 1); // Next video
    }
    if (currentIndex - 1 >= 0) {
      indicesToLoad.add(currentIndex - 1); // Previous video
    }

    // Limit to max concurrent players
    final targetIndices = indicesToLoad.take(kMaxConcurrentPlayers).toList();

    // Mark IDs to keep
    for (final index in targetIndices) {
      idsToKeep.add(videos[index].id);
    }

    // Dispose players not in target list
    final idsToRemove = newPlayers.keys
        .where((id) => !idsToKeep.contains(id))
        .toList();

    for (final id in idsToRemove) {
      final player = newPlayers.remove(id);
      newControllers.remove(
        id,
      ); // Controllers are disposed automatically with player

      if (player != null) {
        await player.pause();
        await player.dispose();
      }
    }

    // Update state after disposal
    state = state.copyWith(players: newPlayers, controllers: newControllers);

    // Initialize new players
    for (final index in targetIndices) {
      final video = videos[index];

      print('  Processing video at index $index: ${video.id}');

      // Skip live streams - they use different player
      if (video.isLiveStream) {
        print('    Skipping: is live stream');
        continue;
      }

      if (!newPlayers.containsKey(video.id)) {
        print('    Creating new player for ${video.id}');
        try {
          // Create player
          final player = Player();
          final controller = mk_video.VideoController(player);

          newPlayers[video.id] = player;
          newControllers[video.id] = controller;

          // Update state immediately so UI can show loading
          state = state.copyWith(
            players: Map.from(newPlayers),
            controllers: Map.from(newControllers),
          );

          print('    Opening media: ${video.videoUrl}');
          // Open media (this initializes the player)
          await player.open(Media(video.videoUrl));
          await player.setPlaylistMode(PlaylistMode.loop);

          // Pause immediately - only the current video with autoplay=true will start
          await player.pause();

          // Update state after successful initialization
          state = state.copyWith(
            players: Map.from(newPlayers),
            controllers: Map.from(newControllers),
          );

          print('MediaKit: Initialized player for video ${video.id}');
        } catch (e) {
          print('MediaKit: Error initializing player for ${video.id}: $e');
          // Remove failed player/controller
          newPlayers.remove(video.id);
          newControllers.remove(video.id);
          state = state.copyWith(
            players: Map.from(newPlayers),
            controllers: Map.from(newControllers),
          );
        }
      } else {
        print('    Player already exists for ${video.id}');
      }
    }
  }

  void pauseAll() {
    for (final player in state.players.values) {
      player.pause();
    }
  }

  void disposeAll() async {
    for (final player in state.players.values) {
      await player.dispose();
    }
    // Controllers are disposed automatically with players
    state = state.copyWith(players: {}, controllers: {});
  }
}

/// Provider for media_kit video management
final mediaKitVideoProvider =
    StateNotifierProvider<MediaKitVideoNotifier, MediaKitVideoState>((ref) {
      return MediaKitVideoNotifier();
    });
