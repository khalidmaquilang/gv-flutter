import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:test_flutter/core/theme/app_theme.dart';
import '../../../feed/data/services/video_service.dart';

import 'package:audioplayers/audioplayers.dart';
import '../../data/models/sound_model.dart';

class PreviewScreen extends StatefulWidget {
  final List<XFile> files;
  final bool isVideo;
  final Sound? sound;

  const PreviewScreen({
    super.key,
    required this.files,
    this.isVideo = true,
    this.sound,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  VideoPlayerController? _videoController;
  AudioPlayer? _musicPlayer;
  int _currentFileIndex = 0;

  bool _isVoiceMuted = false;
  bool _isMusicMuted = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo && widget.files.isNotEmpty) {
      _initializeController(0);
    }
  }

  // Helper to safely play music without blocking video
  Future<void> _tryPlayMusic() async {
    if (widget.sound == null || widget.sound!.url.isEmpty) return;

    // If player exists, just resume (assuming already setup)
    if (_musicPlayer != null) {
      if (_musicPlayer!.state != PlayerState.playing) {
        await _musicPlayer?.resume();
      }
      return;
    }

    // Initialize fresh
    _musicPlayer = AudioPlayer();

    try {
      Source source;
      if (widget.sound!.url.startsWith('assets/')) {
        source = AssetSource(widget.sound!.url.substring(7));
      } else {
        source = UrlSource(widget.sound!.url);
      }

      // Set volume first to avoid blast if unmuted
      await _musicPlayer?.setVolume(_isMusicMuted ? 0 : 1.0);
      await _musicPlayer?.setReleaseMode(ReleaseMode.loop);

      // Play (which includes setSource)
      await _musicPlayer?.play(source);
    } catch (e) {
      debugPrint("PreviewScreen: Music playback failed: $e");
      // Clean up if failed
      _musicPlayer?.dispose();
      _musicPlayer = null;
    }
  }

  Future<void> _initializeController(int index) async {
    try {
      final file = widget.files[index];
      debugPrint("PreviewScreen: Init video $index: ${file.path}");

      final controller = VideoPlayerController.file(File(file.path));
      _videoController = controller;

      await controller.initialize();
      await controller.setVolume(_isVoiceMuted ? 0 : 1.0);

      controller.addListener(() {
        if (controller.value.isInitialized &&
            !controller.value.isPlaying &&
            controller.value.position >= controller.value.duration) {
          _playNext();
        }
      });

      if (mounted) {
        setState(() {});
        // Play video FIRST
        await controller.play();

        // Then try music (fire and forget, don't await) with DELAY
        if (index == 0) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _tryPlayMusic();
          });
        }
      }
    } catch (e) {
      debugPrint("PreviewScreen: Error initializing video: $e");
      if (mounted) _playNext();
    }
  }

  void _playNext() async {
    debugPrint(
      "PreviewScreen: _playNext called. Current Index: $_currentFileIndex",
    );
    if (_currentFileIndex < widget.files.length - 1) {
      _currentFileIndex++;
      await _videoController?.dispose();
      if (!mounted) return;
      _initializeController(_currentFileIndex);
    } else {
      debugPrint("PreviewScreen: Reached end of playlist. Looping.");
      // Loop back to start
      _currentFileIndex = 0;
      await _videoController?.dispose();

      // Reset music position if looping video sequence?
      if (_musicPlayer != null) {
        await _musicPlayer?.seek(Duration.zero);
        await _musicPlayer?.resume(); // Ensure playing
      }

      if (!mounted) return;
      _initializeController(0);
    }
  }

  void _toggleVoiceMute() {
    setState(() {
      _isVoiceMuted = !_isVoiceMuted;
      _videoController?.setVolume(_isVoiceMuted ? 0 : 1.0);
    });
  }

  void _toggleMusicMute() {
    setState(() {
      _isMusicMuted = !_isMusicMuted;
      _musicPlayer?.setVolume(_isMusicMuted ? 0 : 1.0);
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _musicPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If no files, pop
    if (widget.files.isEmpty) return const SizedBox();

    return Scaffold(
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

          // Audio Mixing Controls
          if (widget.isVideo)
            Positioned(
              top: 100,
              right: 16,
              child: Column(
                children: [
                  // Mute Voice (Video Audio)
                  IconButton(
                    onPressed: _toggleVoiceMute,
                    icon: Icon(
                      _isVoiceMuted ? Icons.mic_off : Icons.mic,
                      color: _isVoiceMuted ? Colors.red : Colors.white,
                      size: 30,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                    tooltip: "Toggle Original Sound",
                  ),
                  const SizedBox(height: 10),
                  // Mute Music (Added Sound)
                  if (widget.sound != null)
                    IconButton(
                      onPressed: _toggleMusicMute,
                      icon: Icon(
                        _isMusicMuted ? Icons.music_off : Icons.music_note,
                        color: _isMusicMuted ? Colors.red : Colors.white,
                        size: 30,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                      tooltip: "Toggle Added Sound",
                    ),
                ],
              ),
            ),

          Positioned(
            bottom: 40,
            right: 16,
            child: ElevatedButton(
              onPressed: () async {
                if (widget.files.isEmpty) return;

                // For MVP: Just upload the first segment path.
                final path = widget.files.first.path;

                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("Uploading...")));

                // Call service
                final success = await VideoService().uploadVideo(
                  path,
                  "My cool video #${DateTime.now().second}",
                );

                if (!mounted) return;

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Posted successfully!")),
                  );
                  // Pop to feed (or root)
                  Navigator.of(context).popUntil((route) => route.isFirst);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Upload failed")),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonPink,
              ),
              child: const Text("Post", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
