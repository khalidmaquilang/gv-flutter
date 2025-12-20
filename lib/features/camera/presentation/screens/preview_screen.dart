import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:test_flutter/core/theme/app_theme.dart';
import '../../../feed/presentation/screens/create_post_screen.dart';
import 'video_recorder_screen.dart'; // For Continue Recording

import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/sound_model.dart';
import '../../../feed/presentation/providers/drafts_provider.dart';

class PreviewScreen extends ConsumerStatefulWidget {
  final List<XFile> files;
  final bool isVideo;
  final Sound? sound;
  final String? initialCaption;
  final bool fromDraft;
  final String? draftId;

  const PreviewScreen({
    super.key,
    required this.files,
    this.isVideo = true,
    this.sound,
    this.initialCaption,
    this.fromDraft = false,
    this.draftId,
  });

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  VideoPlayerController? _videoController;
  VideoPlayerController? _nextVideoController;
  AudioPlayer? _musicPlayer;
  int _currentFileIndex = 0;

  bool _isVoiceMuted = false;
  final bool _isMusicMuted = false;

  @override
  void initState() {
    super.initState();
    if (widget.sound != null) {
      _isVoiceMuted = true;
      _initAudio();
    }
    if (widget.isVideo && widget.files.isNotEmpty) {
      if (widget.isVideo && widget.files.isNotEmpty) {
        _loadCurrentAndNext(0);
      }
    }
  }

  Future<void> _initAudio() async {
    // Initialize fresh
    _musicPlayer = AudioPlayer();

    // Prepare session for mixing - Do this ONCE
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.mixWithOthers,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      ),
    );

    try {
      if (widget.sound!.url.startsWith('assets/')) {
        await _musicPlayer?.setAsset(widget.sound!.url);
      } else {
        await _musicPlayer?.setUrl(widget.sound!.url);
      }

      await _musicPlayer?.setVolume(_isMusicMuted ? 0 : 1.0);
      await _musicPlayer?.setLoopMode(LoopMode.one);
      // Ready to play!
    } catch (e) {
      debugPrint("PreviewScreen: Audio init failed: $e");
    }
  }

  void _startMusic() {
    if (_musicPlayer != null && widget.sound != null) {
      _musicPlayer?.play();
    }
  }

  Future<void> _loadCurrentAndNext(int index) async {
    // 1. Load Current (if needed)
    if (_videoController == null) {
      try {
        final file = widget.files[index];
        debugPrint("PreviewScreen: Init current video $index: ${file.path}");
        _videoController = VideoPlayerController.file(
          File(file.path),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
        await _videoController!.initialize();
        await _videoController!.setVolume(_isVoiceMuted ? 0 : 1.0);
        _videoController!.addListener(_videoListener);
        if (mounted) {
          setState(() {});
          await _videoController!.play();

          // Start music on first clip
          if (index == 0) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) _startMusic();
            });
          }
        }
      } catch (e) {
        debugPrint("PreviewScreen: Error initializing current video: $e");
        if (mounted) _playNext();
        return;
      }
    } else {
      // If we reused next controller, ensure it's playing and listening
      if (mounted) {
        setState(() {});
        await _videoController!.play();
        // Ensure music is syncing if not first segment?
        // Logic assumes music plays continuously.
      }
    }

    // 2. Pre-load Next
    int nextIndex = index + 1;
    if (nextIndex >= widget.files.length) {
      nextIndex = 0; // Loop ready
    }

    // Only pre-load if valid and different (single video doesn't need next unless looping itself? no, controller handles loop)
    if (widget.files.length > 1) {
      _preloadNext(nextIndex);
    }
  }

  Future<void> _preloadNext(int nextIndex) async {
    // Dispose old next if exists (shoudn't unless rapid skip)
    if (_nextVideoController != null) {
      await _nextVideoController!.dispose();
    }

    try {
      final file = widget.files[nextIndex];
      debugPrint(
        "PreviewScreen: Pre-loading next video $nextIndex: ${file.path}",
      );
      _nextVideoController = VideoPlayerController.file(
        File(file.path),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await _nextVideoController!.initialize();
      await _nextVideoController!.setVolume(_isVoiceMuted ? 0 : 1.0);
      // Don't add listener or play yet
    } catch (e) {
      debugPrint("PreviewScreen: Error pre-loading next: $e");
    }
  }

  void _videoListener() {
    final controller = _videoController;
    if (controller != null &&
        controller.value.isInitialized &&
        !controller.value.isPlaying &&
        controller.value.position >= controller.value.duration) {
      _playNext();
    }
  }

  // Replaces _initializeController
  // Future<void> _initializeController(int index) async ... DELETED via replace

  void _playNext() async {
    debugPrint("PreviewScreen: _playNext called. Current: $_currentFileIndex");

    // Swap Next to Current
    if (_videoController != null) {
      _videoController!.removeListener(_videoListener);
      await _videoController!.dispose();
      _videoController = null;
    }

    if (_currentFileIndex < widget.files.length - 1) {
      _currentFileIndex++;
    } else {
      _currentFileIndex = 0;
      // Reset Music Loop
      if (_musicPlayer != null) {
        await _musicPlayer?.seek(Duration.zero);
        if (!_isMusicMuted) _musicPlayer?.play();
      }
    }

    // Use Pre-loaded
    if (_nextVideoController != null &&
        _nextVideoController!.value.isInitialized) {
      _videoController = _nextVideoController;
      _nextVideoController = null;
      _videoController!.addListener(_videoListener);
      // Play immediately
      await _videoController!.play();
      if (mounted) setState(() {});

      // Trigger pre-load for the one AFTER this new one
      if (widget.files.length > 1) {
        int nextNextIndex = _currentFileIndex + 1;
        if (nextNextIndex >= widget.files.length) nextNextIndex = 0;
        _preloadNext(nextNextIndex);
      }
    } else {
      // Fallback if pre-load failed or wasn't ready
      _loadCurrentAndNext(_currentFileIndex);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _nextVideoController?.dispose();
    _musicPlayer?.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!widget.fromDraft) return true;

    // Show Options Dialog
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.save, color: Colors.white),
              title: const Text(
                "Save and Exit",
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.of(context).pop('save'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.white),
              title: const Text(
                "Continue Recording",
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.of(context).pop('record'),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );

    if (result == 'save') {
      return true; // Pop
    } else if (result == 'record') {
      if (!mounted) return false;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => VideoRecorderScreen(
            initialFiles: widget.files,
            draftId: widget.draftId,
            initialSound: widget.sound,
          ),
        ),
      );
      return false; // Don't pop, we pushed replacement
    }

    return false; // Dismissed dialog without choice
  }

  @override
  Widget build(BuildContext context) {
    // If no files, pop
    if (widget.files.isEmpty) return const SizedBox();

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: widget.isVideo
                  ? (_videoController != null &&
                            _videoController!.value.isInitialized
                        ? AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          )
                        : const CircularProgressIndicator())
                  : Image.file(
                      File(widget.files.first.path),
                      fit: BoxFit.contain,
                    ),
            ),

            // Back Button
            Positioned(
              top: 60,
              left: 20,
              child: IconButton(
                onPressed: () async {
                  if (await _onWillPop()) {
                    if (mounted) Navigator.of(context).pop();
                  }
                },
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: Colors.white,
                  size: 30,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ),
            ),

            // Progress Indication
            if (widget.files.length > 1)
              Positioned(
                top: 60,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    "${_currentFileIndex + 1} / ${widget.files.length}",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),

            // Delete Draft Button
            if (widget.fromDraft && widget.draftId != null)
              Positioned(
                top: 60,
                right: widget.files.length > 1 ? 80 : 20, // Adjust if conflict
                child: GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Colors.grey[900],
                        title: const Text(
                          "Delete Draft?",
                          style: TextStyle(color: Colors.white),
                        ),
                        content: const Text(
                          "This action cannot be undone.",
                          style: TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () {
                              ref
                                  .read(draftsControllerProvider.notifier)
                                  .deleteDraft(widget.draftId!);
                              Navigator.of(context).pop(); // Dialog
                              Navigator.of(
                                context,
                              ).pop(); // Preview (back to list)
                            },
                            child: const Text(
                              "Delete",
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.red.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.red,
                      size: 24,
                    ),
                  ),
                ),
              ),

            Positioned(
              bottom: 40,
              right: 16,
              child: ElevatedButton(
                onPressed: () {
                  if (widget.files.isEmpty) return;

                  // Pause playback before navigating
                  _videoController?.pause();
                  _musicPlayer?.pause();

                  // Navigate to CreatePostScreen
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CreatePostScreen(
                        files: widget.files,
                        isVideo: widget.isVideo,
                        sound: widget.sound,
                        initialCaption: widget.initialCaption,
                        draftId: widget.draftId,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonPink,
                ),
                child: const Text(
                  "Next",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
