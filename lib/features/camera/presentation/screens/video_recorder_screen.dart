import 'dart:async';
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

  List<XFile> _recordedFiles = [];
  Timer? _timer;
  List<double> _segments = [];
  double _currentSegmentProgress = 0.0;
  int _maxDuration = 15;
  bool isPaused = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onModeChanged(int index) {
    if (isRecording || isPaused) return;
    setState(() {
      _selectedModeIndex = index;
    });

    if (_modes[index] == 'Live') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LiveStreamSetupScreen()),
      );
      return;
    }

    if (_modes[index] == '15s') {
      _maxDuration = 15;
    } else if (_modes[index] == '60s') {
      _maxDuration = 60;
    } else {
      _maxDuration = 0;
    }

    if (isRecording) {
      _recordVideo();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    int ticks = 0;
    int totalTicks = _maxDuration * 10;

    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;

      setState(() {
        ticks++;
        if (totalTicks > 0) {
          _currentSegmentProgress = ticks / totalTicks;
        } else {
          _currentSegmentProgress = 0.0;
        }
      });

      double totalProgress =
          _segments.fold(0.0, (sum, seg) => sum + seg) +
          _currentSegmentProgress;

      if (_maxDuration > 0 && totalProgress >= 1.0) {
        _timer?.cancel(); // Cancel timer immediately
        _finishRecording(); // Finish directly without pausing
      }
    });
  }

  void _pauseTimer() async {
    _timer?.cancel();
    debugPrint("Recorder: Pausing... Stopping current segment.");
    final file = await ref
        .read(cameraControllerProvider.notifier)
        .stopRecording();

    if (!mounted) return;
    setState(() {
      if (file != null) {
        debugPrint("Recorder: Segment saved. Path: ${file.path}");
        _recordedFiles.add(file);
        _segments.add(_currentSegmentProgress);
      } else {
        debugPrint("Recorder: Stop returned NULL file!");
      }
      _currentSegmentProgress = 0.0;
      isPaused = true;
      isRecording = false;
    });
  }

  void _resumeTimer() async {
    debugPrint("Recorder: Resuming... Starting new segment.");
    await ref.read(cameraControllerProvider.notifier).startRecording();

    if (!mounted) return;
    setState(() {
      isPaused = false;
      isRecording = true;
    });
    _startTimer();
  }

  void _discardLastSegment() async {
    if (_recordedFiles.isEmpty) return;

    debugPrint("Recorder: Discarding last segment.");
    setState(() {
      _recordedFiles.removeLast();
      if (_segments.isNotEmpty) {
        _segments.removeLast();
      }
      if (_recordedFiles.isEmpty) {
        isPaused = false;
        isRecording = false;
        _currentSegmentProgress = 0.0;
      }
    });
  }

  Future<void> _finishRecording() async {
    _timer?.cancel();
    debugPrint(
      "Recorder: Finishing... Files count before stop: ${_recordedFiles.length}",
    );

    if (isRecording) {
      final file = await ref
          .read(cameraControllerProvider.notifier)
          .stopRecording();
      if (file != null) {
        debugPrint("Recorder: Saved final segment: ${file.path}");
        _recordedFiles.add(file);
      } else {
        debugPrint("Recorder: Final segment stop returned NULL");
      }
    }

    debugPrint("Recorder: Total Files to Preview: ${_recordedFiles.length}");

    if (!mounted) return;

    final filesToPreview = List<XFile>.from(_recordedFiles);

    setState(() {
      isRecording = false;
      isPaused = false;
      _segments.clear();
      _currentSegmentProgress = 0.0;
      _recordedFiles.clear();
    });

    if (filesToPreview.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              PreviewScreen(files: filesToPreview, isVideo: true),
        ),
      );
    } else {
      debugPrint(
        "Recorder: ERROR - filesToPreview is EMPTY! Cannot push preview.",
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No video recorded!")));
    }
  }

  void _recordVideo() async {
    final notifier = ref.read(cameraControllerProvider.notifier);

    // Photo Mode
    if (_modes[_selectedModeIndex] == 'Photo') {
      final file = await notifier.takePicture();
      if (file != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PreviewScreen(files: [file], isVideo: false),
          ),
        );
      }
      return;
    }

    // Video Mode
    if (isRecording) {
      _pauseTimer();
    } else if (isPaused) {
      _resumeTimer();
    } else {
      await notifier.startRecording();
      setState(() {
        isRecording = true;
        isPaused = false;
        _recordedFiles.clear();
        _segments.clear();
        _currentSegmentProgress = 0.0;
      });
      _startTimer();
    }
  }

  void _pickFromGallery() async {
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
              Center(child: CameraPreview(controller)),

              // Top Actions
              Positioned(
                top: 48,
                left: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),

              // Select Sound
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

              // Bottom Area
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
                          // Gallery/Discard
                          if (!isRecording && !isPaused)
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
                                        ),
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
                            )
                          else if (isPaused && _segments.isNotEmpty)
                            IconButton(
                              onPressed: _discardLastSegment,
                              icon: const Icon(
                                Icons.backspace,
                                color: Colors.white,
                                size: 30,
                              ),
                            )
                          else
                            const SizedBox(width: 36),

                          // Record Button
                          GestureDetector(
                            onTap: _recordVideo,
                            child: SizedBox(
                              height: 80,
                              width: 80,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    height: 80,
                                    width: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isRecording
                                            ? Colors.transparent
                                            : const Color(
                                                0xFFFE2C55,
                                              ).withOpacity(0.5),
                                        width: 6,
                                      ),
                                    ),
                                  ),
                                  if (isRecording || isPaused)
                                    SizedBox(
                                      height: 80,
                                      width: 80,
                                      child: CustomPaint(
                                        painter: SegmentedRingPainter(
                                          segments: _segments,
                                          currentProgress:
                                              _currentSegmentProgress,
                                          color: const Color(0xFFFE2C55),
                                          strokeWidth: 6,
                                        ),
                                      ),
                                    ),
                                  Center(
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
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
                                  if (isPaused)
                                    const Center(
                                      child: Icon(
                                        Icons.play_arrow,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          // Checkmark
                          if (isPaused && _segments.isNotEmpty)
                            IconButton(
                              onPressed: _finishRecording,
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFE2C55),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            )
                          else
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

class SegmentedRingPainter extends CustomPainter {
  final List<double> segments;
  final double currentProgress;
  final Color color;
  final double strokeWidth;

  SegmentedRingPainter({
    required this.segments,
    required this.currentProgress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt; // Butt cap for cleaner segments

    // Draw completed segments
    double startAngle = -3.14159 / 2; // Start from top (-90 degrees)

    // Draw each completed segment
    for (final segment in segments) {
      final sweepAngle = segment * 2 * 3.14159;
      // Subtract a small gap if it's not the very end
      final drawAngle = sweepAngle > 0.02 ? sweepAngle - 0.05 : sweepAngle;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        drawAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }

    // Draw current progress
    if (currentProgress > 0) {
      final sweepAngle = currentProgress * 2 * 3.14159;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SegmentedRingPainter oldDelegate) {
    return oldDelegate.currentProgress != currentProgress ||
        oldDelegate.segments != segments;
  }
}
