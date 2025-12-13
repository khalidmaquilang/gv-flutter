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
  int _selectedModeIndex = 1; // 0: Photo, 1: 15s, 2: 60s, 3: Live
  final List<String> _modes = ['Photo', '15s', '60s', 'Live'];

  // Timer logic
  // int _recordDuration = 0; // Removed unused field

  void _onModeChanged(int index) {
    setState(() {
      _selectedModeIndex = index;
    });

    if (_modes[index] == 'Live') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LiveStreamSetupScreen()),
      );
    }
  }

  void _recordVideo() async {
    final notifier = ref.read(cameraControllerProvider.notifier);

    if (_modes[_selectedModeIndex] == 'Photo') {
      final file = await notifier.takePicture();
      if (file != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PreviewScreen(file: file, isVideo: false),
          ),
        );
      }
      return;
    }

    if (isRecording) {
      // Stop
      final file = await notifier.stopRecording();
      setState(() => isRecording = false);
      if (file != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PreviewScreen(file: file, isVideo: true),
          ),
        );
      }
    } else {
      // Start
      await notifier.startRecording();
      setState(() => isRecording = true);

      // Handle Auto Stop for 15s/60s
      if (_modes[_selectedModeIndex] == '15s' ||
          _modes[_selectedModeIndex] == '60s') {
        int limit = _modes[_selectedModeIndex] == '15s' ? 15 : 60;
        Future.delayed(Duration(seconds: limit), () {
          if (mounted && isRecording) {
            _recordVideo(); // Stop automatically
          }
        });
      }
    }
  }

  void _pickFromGallery() async {
    // Todo: Implement Gallery Picker
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Open Gallery")));
  }

  void _selectSound() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Select Sound")));
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

              // Select Sound (Top Center)
              Positioned(
                top: 48,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: _selectSound,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.music_note, color: Colors.white, size: 16),
                          SizedBox(width: 5),
                          Text(
                            "Add Sound",
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                      onPressed: () {
                        ref
                            .read(cameraControllerProvider.notifier)
                            .switchCamera();
                      },
                    ),
                    const Text(
                      "Flip",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),

              // Bottom Area: Record Button, Gallery, Modes
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    // Controls Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Gallery Button
                          GestureDetector(
                            onTap: _pickFromGallery,
                            child: Column(
                              children: [
                                Container(
                                  height: 36,
                                  width: 36,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    image: const DecorationImage(
                                      image: NetworkImage(
                                        "https://picsum.photos/50",
                                      ), // Placeholder
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  "Upload",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Record Button
                          GestureDetector(
                            onTap: _recordVideo,
                            child: Container(
                              height: 80,
                              width: 80,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(
                                    0xFFFE2C55,
                                  ).withOpacity(0.5),
                                  width: 6,
                                ),
                              ),
                              child: Center(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  height: isRecording ? 30 : 60,
                                  width: isRecording ? 30 : 60,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFE2C55),
                                    borderRadius: BorderRadius.circular(
                                      isRecording ? 6 : 30,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Placeholder for right side symmetry (Effects?)
                          const SizedBox(width: 36),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Mode Selector
                    SizedBox(
                      height: 30,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        shrinkWrap: true,
                        itemCount: _modes.length,
                        itemBuilder: (context, index) {
                          bool isSelected = _selectedModeIndex == index;
                          return GestureDetector(
                            onTap: () => _onModeChanged(index),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                              ),
                              child: Text(
                                _modes[index],
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
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

// Temporary Placeholder for Live Setup until implemented
class LiveStreamSetupScreen extends StatelessWidget {
  const LiveStreamSetupScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: const Center(
        child: Text("Live Stream Setup", style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
