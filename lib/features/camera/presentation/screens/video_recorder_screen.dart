import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/camera_provider.dart';
import 'preview_screen.dart';

class VideoRecorderScreen extends ConsumerStatefulWidget {
  const VideoRecorderScreen({super.key});

  @override
  ConsumerState<VideoRecorderScreen> createState() =>
      _VideoRecorderScreenState();
}

class _VideoRecorderScreenState extends ConsumerState<VideoRecorderScreen> {
  bool isRecording = false;

  void _recordVideo() async {
    final notifier = ref.read(cameraControllerProvider.notifier);

    if (isRecording) {
      // Stop
      final file = await notifier.stopRecording();
      setState(() => isRecording = false);
      if (file != null) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PreviewScreen(videoFile: file),
          ),
        );
      }
    } else {
      // Start
      await notifier.startRecording();
      setState(() => isRecording = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraControllerProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: cameraState.when(
        data: (controller) {
          if (controller == null || !controller.value.isInitialized) {
            return const Center(child: Text("Camera not initialized"));
          }
          return Stack(
            children: [
              // Camera Preview
              Center(child: CameraPreview(controller)),

              // Top Actions (Close, Sound, Flip)
              Positioned(
                top: 48,
                left: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Positioned(
                top: 48,
                right: 16,
                child: Column(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.flip_camera_ios,
                        color: Colors.white,
                      ),
                      onPressed: () {}, // Todo: Flip
                    ),
                    const Text(
                      "Flip",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),

              // Bottom Actions (Record Button)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: _recordVideo,
                    child: Container(
                      height: 80,
                      width: 80,
                      decoration: BoxDecoration(
                        color: isRecording ? Colors.red : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: isRecording
                          ? Center(
                              child: Container(
                                height: 30,
                                width: 30,
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.rectangle,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        error: (err, st) => Center(child: Text("Error: $err")),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
