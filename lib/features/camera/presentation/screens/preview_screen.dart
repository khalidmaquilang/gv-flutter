import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class PreviewScreen extends StatefulWidget {
  final List<XFile> files;
  final bool isVideo;

  const PreviewScreen({super.key, required this.files, this.isVideo = true});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  VideoPlayerController? _videoController;
  int _currentFileIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo && widget.files.isNotEmpty) {
      _initializeController(0);
    }
  }

  Future<void> _initializeController(int index) async {
    try {
      final file = widget.files[index];
      debugPrint(
        "PreviewScreen: Initializing video index $index: ${file.path}",
      );

      final controller = VideoPlayerController.file(File(file.path));
      _videoController = controller;

      await controller.initialize();
      debugPrint(
        "PreviewScreen: Video initialized. Duration: ${controller.value.duration}",
      );

      // Simple sequential playback listener
      controller.addListener(() {
        // Check if playing and reached end
        if (controller.value.isInitialized &&
            !controller.value.isPlaying &&
            controller.value.position >= controller.value.duration) {
          debugPrint("PreviewScreen: Video $index ended. Playing next.");
          _playNext();
        }
      });

      if (mounted) {
        setState(() {});
        await controller.play();
      }
    } catch (e) {
      debugPrint("PreviewScreen: Error initializing video: $e");
      if (mounted) {
        // Show error or skip?
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error playing clip $index: $e")),
        );
        _playNext(); // Try next if fail
      }
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
      if (!mounted) return;
      _initializeController(0);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
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
          // Progress indicator for multiple segments?
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

          // Debug Info Overlay (Temporary)
          if (_videoController != null)
            Positioned(
              top: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.black54,
                child: Text(
                  "Debug Info:\n"
                  "File: ${widget.files[_currentFileIndex].path.split('/').last}\n"
                  "Init: ${_videoController!.value.isInitialized}\n"
                  "Playing: ${_videoController!.value.isPlaying}\n"
                  "Pos: ${_videoController!.value.position}\n"
                  "Dur: ${_videoController!.value.duration}\n"
                  "Ratio: ${_videoController!.value.aspectRatio}\n"
                  "Error: ${_videoController!.value.errorDescription}",
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),

          Positioned(
            top: 48,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            bottom: 40,
            right: 16,
            child: ElevatedButton(
              onPressed: () {
                // Todo: Upload Logic (Pass list of files)
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "Uploading ${widget.isVideo ? 'Video (${widget.files.length} clips)' : 'Photo'}... (Mock)",
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFE2C55),
              ),
              child: const Text("Post", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
