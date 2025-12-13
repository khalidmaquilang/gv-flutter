import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:test_flutter/core/theme/app_theme.dart';
import '../../../feed/data/services/video_service.dart';

import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
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
    if (widget.sound != null) {
      _isVoiceMuted = true;
      _initAudio();
    }
    if (widget.isVideo && widget.files.isNotEmpty) {
      _initializeController(0);
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

  Future<void> _initializeController(int index) async {
    try {
      final file = widget.files[index];
      debugPrint("PreviewScreen: Init video $index: ${file.path}");

      final controller = VideoPlayerController.file(
        File(file.path),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
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

        // Then start music (should be preloaded or loading) with DELAY
        if (index == 0) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _startMusic();
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
        if (!_isMusicMuted) _musicPlayer?.play();
      }

      if (!mounted) return;
      _initializeController(0);
    }
  }

  void _toggleVoiceMute() {
    setState(() {
      _isVoiceMuted = !_isVoiceMuted;
      _videoController?.setVolume(_isVoiceMuted ? 0 : 1.0);
      debugPrint("PreviewScreen: Voice Muted: $_isVoiceMuted");
    });
  }

  void _toggleMusicMute() {
    setState(() {
      _isMusicMuted = !_isMusicMuted;
      _musicPlayer?.setVolume(_isMusicMuted ? 0 : 1.0);
      debugPrint("PreviewScreen: Music Muted: $_isMusicMuted");
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

          // Back Button
          Positioned(
            top: 60,
            left: 20,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
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

          // Audio Mixing Controls (Only show if NO sound is selected)
          if (widget.isVideo && widget.sound == null)
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
