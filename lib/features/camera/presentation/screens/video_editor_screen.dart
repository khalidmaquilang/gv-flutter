import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_editor/video_editor.dart';
import 'package:test_flutter/core/theme/app_theme.dart';

class VideoEditorScreen extends StatefulWidget {
  final File file;

  const VideoEditorScreen({super.key, required this.file});

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  late VideoEditorController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoEditorController.file(
      widget.file,
      minDuration: const Duration(seconds: 1),
      maxDuration: const Duration(seconds: 60),
    );
    _controller
        .initialize()
        .then((_) {
          setState(() {});
        })
        .catchError((error) {
          debugPrint("Error initializing video editor: $error");
          Navigator.pop(context); // Go back if error
        });
  }

  @override
  void dispose() {
    // _controller.dispose(); // VideoEditorController disposes the video player, but we might want to keep it if we passed it? No, we created it.
    _controller.dispose();
    super.dispose();
  }

  void _exportVideo() async {
    // Since we don't have FFMPEG, we will just return the trimmed range.
    // The calling screen (PreviewScreen) will handle "playing" the trimmed part.
    // Or if we had ffmpeg, we would run the export command here.

    // For now, we return the start and end offsets.
    final start = _controller.startTrim;
    final end = _controller.endTrim;

    Navigator.pop(context, {'start': start, 'end': end});
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.initialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Edit Video', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _exportVideo,
            child: const Text(
              "Done",
              style: TextStyle(
                color: AppColors.neonPink,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                CropGridViewer.preview(controller: _controller),
                AnimatedBuilder(
                  animation: _controller.video,
                  builder: (_, __) => AnimatedOpacity(
                    opacity: _controller.isPlaying ? 0 : 1,
                    duration: kThemeAnimationDuration,
                    child: GestureDetector(
                      onTap: _controller.video.play,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(20),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 200,
            padding: const EdgeInsets.only(top: 20),
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: TrimSlider(controller: _controller, height: 60),
                      ),
                      const SizedBox(height: 10),
                      // Play/Pause button for previewing trim
                      IconButton(
                        onPressed: () {
                          if (_controller.isPlaying) {
                            _controller.video.pause();
                          } else {
                            _controller.video.play();
                          }
                          setState(() {});
                        },
                        icon: Icon(
                          _controller.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                          color: Colors.white,
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
    );
  }
}
