import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../data/models/video_model.dart';

class VideoPreloadState {
  final Map<String, VideoPlayerController> controllers;

  VideoPreloadState({this.controllers = const {}});

  VideoPreloadState copyWith({
    Map<String, VideoPlayerController>? controllers,
  }) {
    return VideoPreloadState(controllers: controllers ?? this.controllers);
  }
}

class VideoPreloadNotifier extends StateNotifier<VideoPreloadState> {
  VideoPreloadNotifier() : super(VideoPreloadState());

  // Max number of simultaneous decoders.
  // 2 is safe for most devices. 3 might be okay on high-end.
  static const int kMaxConcurrentControllers = 2;

  Future<void> onPageChanged(int currentIndex, List<Video> videos) async {
    final newControllers = Map<String, VideoPlayerController>.from(
      state.controllers,
    );
    final idsToKeep = <String>{};

    // Determine target indices to preload
    // Priority 1: Current Video
    // Priority 2: Next Video
    // Priority 3: Previous Video (only if we have space)

    final indicesToLoad = <int>[];
    indicesToLoad.add(currentIndex);
    if (currentIndex + 1 < videos.length) indicesToLoad.add(currentIndex + 1);
    if (currentIndex - 1 >= 0) indicesToLoad.add(currentIndex - 1);

    // Filter indices based on max concurrency
    // We take the first N from our priority list
    final targetIndices = indicesToLoad
        .take(kMaxConcurrentControllers)
        .toList();

    // 1. Identification Phase
    for (final index in targetIndices) {
      idsToKeep.add(videos[index].id);
    }

    // 2. Disposal Phase (Free up resources FIRST)
    // Remove controllers that are not in our target list
    final idsToRemove = newControllers.keys
        .where((id) => !idsToKeep.contains(id))
        .toList();
    for (final id in idsToRemove) {
      final controller = newControllers.remove(id);
      if (controller != null) {
        // Pause before dispose to stop audio immediately
        controller.pause();
        controller.dispose();
      }
    }

    // Update state immediately after disposal to reflect freed resources (conceptually)
    // But we will do a single state update at the end or incrementally?
    // Let's do it at the end to avoid UI flickering, but we must ensure we don't
    // init new ones before disposing old ones if we are strictly hitting the limit.
    // The explicit dispose calls above freed the native resources.

    state = state.copyWith(controllers: newControllers);

    // 3. Initialization Phase
    for (final index in targetIndices) {
      final video = videos[index];
      if (!newControllers.containsKey(video.id)) {
        // Initialize new controller
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(video.videoUrl),
        );
        newControllers[video.id] = controller;

        // We put it in the map immediately so UI can show "loading"
        state = state.copyWith(controllers: Map.from(newControllers));

        try {
          await controller.initialize();
          controller.setLooping(true);
          // Notify UI that it's ready (needed for AspectRatio etc)
          // We trigger a state update by creating a new map
          state = state.copyWith(controllers: Map.from(newControllers));
        } catch (e) {
          print("Error initializing video ${video.id}: $e");
          // Remove failed controller
          newControllers.remove(video.id);
          state = state.copyWith(controllers: Map.from(newControllers));
        }
      }
    }
  }

  void pauseCurrentVideo() {
    // Pause all active video controllers
    for (final controller in state.controllers.values) {
      if (controller.value.isPlaying) {
        controller.pause();
      }
    }
  }

  void disposeAll() {
    for (final controller in state.controllers.values) {
      controller.dispose();
    }
    state = state.copyWith(controllers: {});
  }
}

final videoPreloadProvider =
    StateNotifierProvider<VideoPreloadNotifier, VideoPreloadState>((ref) {
      return VideoPreloadNotifier();
    });
