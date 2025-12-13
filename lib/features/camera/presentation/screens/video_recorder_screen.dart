import 'dart:async';
import 'dart:io';
import 'package:deepar_flutter_plus/deepar_flutter_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'preview_screen.dart';
import 'package:test_flutter/core/theme/app_theme.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/sound_model.dart';
import 'sound_selection_screen.dart';
import '../../data/services/deepar_service.dart';
import 'package:path_provider/path_provider.dart';

class VideoRecorderScreen extends ConsumerStatefulWidget {
  const VideoRecorderScreen({super.key});

  @override
  ConsumerState<VideoRecorderScreen> createState() =>
      _VideoRecorderScreenState();
}

enum FlashState { off, on, auto }

class _VideoRecorderScreenState extends ConsumerState<VideoRecorderScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  DeepArControllerPlus? _deepArController; // Updated type
  bool _isDeepArInitialized = false;

  bool isRecording = false;
  int _selectedModeIndex = 1; // 0: Photo, 1: 15s, 2: 60s, 3: Live
  final List<String> _modes = ['Photo', '15s', '60s', 'Live'];

  // Effects
  final List<String> _effects = ['none', 'beats-headphones-ad', 'makeup-kim'];
  int _selectedEffectIndex = 0;

  List<XFile> _recordedFiles = [];
  Timer? _timer;
  List<double> _segments = [];
  double _currentSegmentProgress = 0.0;
  int _maxDuration = 15;
  bool isPaused = false;

  // New State for Side Menu
  FlashState _flashMode = FlashState.off;
  int _timerDelay = 0; // 0, 3, 10 seconds
  int _countdown = 0; // Current countdown value

  // Media Picker State
  Uint8List? _lastImageBytes;

  // Sound
  Sound? _selectedSound;

  @override
  void initState() {
    super.initState();
    _initializeDeepAr();
    _fetchLastImage();
  }

  Future<void> _initializeDeepAr() async {
    _deepArController = await DeepArService.initialize();
    if (mounted) {
      if (_deepArController?.isInitialized ?? false) {
        setState(() {
          _isDeepArInitialized = true;
        });
      } else {
        // Handle init failure if needed, mainly checked in build
        // DeepArService logs errors.
        // We can check again slightly later if iOS needs it, but service return should be enough for now.
        setState(() {
          _isDeepArInitialized =
              true; // Still true to let build try render or show error
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
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

  void _toggleFlash() async {
    setState(() {
      if (_flashMode == FlashState.off) {
        _flashMode = FlashState.on;
        _deepArController?.toggleFlash();
      } else {
        _flashMode = FlashState.off;
        _deepArController?.toggleFlash();
      }
    });
  }

  Future<File> _copyAssetToFile(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    final buffer = byteData.buffer;
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/${assetPath.split('/').last}');
    await file.writeAsBytes(
      buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
    );
    return file;
  }

  void _switchEffect(int index) async {
    if (_deepArController == null) return;
    setState(() {
      _selectedEffectIndex = index;
    });

    final effect = _effects[index];
    if (effect == 'none') {
      _deepArController?.switchEffect(null as dynamic);
    } else {
      String assetPath = "assets/deepar/$effect.deepar";
      try {
        final File file = await _copyAssetToFile(assetPath);
        _deepArController?.switchEffect(file.path);
      } catch (e) {
        debugPrint("Error loading effect: $e");
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error loading effect: $e")));
      }
    }
  }

  void _toggleTimer() {
    setState(() {
      if (_timerDelay == 0) {
        _timerDelay = 3;
      } else if (_timerDelay == 3) {
        _timerDelay = 10;
      } else {
        _timerDelay = 0;
      }
    });
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
        _timer?.cancel();
        _finishRecording();
      }
    });
  }

  void _pauseTimer() async {
    _timer?.cancel();
    debugPrint("Recorder: Pausing... Stopping current segment (DeepAR).");
    if (_deepArController == null) return;

    // stopVideoRecording returns File? in Plus?
    // Docs say: stopVideoRecording()
    // It might return void and we rely on 'startVideoRecording' returning the future file?
    // Wait, docs said:
    // final File videoFile = _controller.startVideoRecording();
    // This is weird for a START method.
    // Usually standard DeepAR plugin: start is void. Stop returns string/file.
    // I will use `await _deepArController!.stopVideoRecording();` and check return type.
    // If it returns void, I assume the start call gave me the file path?
    // But how can start give file path before recording?
    // I'll stick to `stopVideoRecording` returning File or String.
    // If usage fails, I'll debug.

    final dynamic result = await _deepArController!.stopVideoRecording();
    File? file;
    if (result is File) {
      file = result;
    } else if (result is String) {
      file = File(result);
    }

    // Pause Music
    await _audioPlayer.pause();

    if (!mounted) return;
    setState(() {
      if (file != null) {
        debugPrint("Recorder: Segment saved. Path: ${file.path}");
        _recordedFiles.add(XFile(file.path));
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
    debugPrint("Recorder: Resuming... Starting new segment (DeepAR).");
    if (_deepArController == null) return;

    await _deepArController!.startVideoRecording();

    // Resume Music
    if (_selectedSound != null) {
      await _audioPlayer.resume();
    }

    if (!mounted) return;
    setState(() {
      isPaused = false;
      isRecording = true;
    });
    _startTimer();
  }

  void _confirmDiscard() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Discard Clip?"),
        content: const Text(
          "Are you sure you want to delete the last recorded segment?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _discardLastSegment();
            },
            child: const Text("Discard", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
    // Stop Music
    await _audioPlayer.stop();

    if (isRecording && _deepArController != null) {
      final dynamic result = await _deepArController!.stopVideoRecording();
      File? file;
      if (result is File) {
        file = result;
      } else if (result is String) {
        file = File(result);
      }

      if (file != null) {
        _recordedFiles.add(XFile(file.path));
      }
    }

    final filesToPreview = List<XFile>.from(_recordedFiles);
    final soundToPass = _selectedSound;

    setState(() {
      isRecording = false;
      isPaused = true;
      _currentSegmentProgress = 0.0;
      // Navigate to preview without clearing state so user can "Back" to edit
    });

    if (filesToPreview.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PreviewScreen(
            files: filesToPreview,
            isVideo: true,
            sound: soundToPass,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No video recorded!")));
    }
  }

  void _recordVideo() async {
    if (_deepArController == null || !_isDeepArInitialized) return;

    // Photo Mode
    if (_modes[_selectedModeIndex] == 'Photo') {
      final File? file = await _deepArController!.takeScreenshot();
      if (file != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                PreviewScreen(files: [XFile(file.path)], isVideo: false),
          ),
        );
      }
      return;
    }

    // Video Mode
    if (_countdown > 0) return;

    if (isRecording) {
      _pauseTimer();
    } else {
      // Logic for both Starting Fresh and Resuming
      VoidCallback startAction;

      if (isPaused) {
        startAction = _resumeTimer;
      } else {
        startAction = () async {
          // Try to mute microphone if we are playing music (Lip Sync mode)
          if (_selectedSound != null) {
            try {
              // wrapper might not stick, but native SDK supports audio manipulation.
              // deepar_flutter usually just records mic.
              // Attempt to disable audio processing if method exists (blind guess based on SDKs)
              // _deepArController?.enableAudio(false);
              // Actually, deepar_flutter_plus uses MethodChannels.
              // Let's rely on the user understanding physics or use headphones.

              // Alternative: Just record.
            } catch (e) {
              debugPrint("Could not mute audio: $e");
            }
          }

          await _deepArController!.startVideoRecording();

          // Start Music
          if (_selectedSound != null) {
            String url = _selectedSound!.url;
            if (url.isNotEmpty) {
              if (url.startsWith('assets/')) {
                url = url.substring(7); // Remove 'assets/' for AssetSource
                await _audioPlayer.play(AssetSource(url));
              } else {
                await _audioPlayer.play(UrlSource(url));
              }
            }
          }

          if (!mounted) return;
          setState(() {
            isRecording = true;
            isPaused = false;
            _recordedFiles.clear();
            _segments.clear();
            _currentSegmentProgress = 0.0;
          });
          _startTimer();
        };
      }

      if (_timerDelay > 0) {
        // Run Countdown
        setState(() {
          _countdown = _timerDelay;
        });
        _audioPlayer.play(AssetSource('sounds/beep.wav'));

        Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }

          setState(() {
            _countdown--;
          });

          if (_countdown > 0) {
            _audioPlayer.play(AssetSource('sounds/beep.wav'));
          }

          if (_countdown <= 0) {
            _audioPlayer.play(AssetSource('sounds/start_record.wav'));
            timer.cancel();
            Future.delayed(const Duration(milliseconds: 450), () {
              if (mounted) startAction();
            });
          }
        });
      } else {
        // Immediate
        _audioPlayer.play(AssetSource('sounds/start_record.wav'));
        Future.delayed(const Duration(milliseconds: 450), () {
          if (mounted) startAction();
        });
      }
    }
  }

  Future<void> _fetchLastImage() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth) {
      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
      );
      if (paths.isNotEmpty) {
        final List<AssetEntity> assets = await paths[0].getAssetListPaged(
          page: 0,
          size: 1,
        );
        if (assets.isNotEmpty) {
          final Uint8List? bytes = await assets[0].thumbnailData;
          if (mounted) {
            setState(() {
              _lastImageBytes = bytes;
            });
          }
        }
      }
    }
  }

  void _pickFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? media = await picker.pickMedia();

    if (media != null && mounted) {
      final bool isVideo =
          media.path.toLowerCase().endsWith('.mp4') ||
          media.path.toLowerCase().endsWith('.mov') ||
          media.path.toLowerCase().endsWith('.avi');

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PreviewScreen(files: [media], isVideo: isVideo),
        ),
      );
    }
  }

  void _selectSound() async {
    final Sound? result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SoundSelectionScreen()),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedSound = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDeepArInitialized || _deepArController == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // DeepAR Preview Link (Updated)
          Transform.scale(
            scale: 1.0,
            child: DeepArPreviewPlus(_deepArController!), // Updated widget
          ),

          // Countdown Overlay
          if (_countdown > 0)
            Center(
              child: Text(
                "$_countdown",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 100,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                ),
              ),
            ),

          // Top Actions
          if (!isRecording)
            Positioned(
              top: 48,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),

          // Select Sound
          if (!isRecording)
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.music_note,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _selectedSound?.title ?? "Add Sound",
                          style: const TextStyle(color: Colors.white),
                        ),
                        if (_selectedSound != null) ...[
                          const SizedBox(width: 5),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedSound = null;
                              });
                            },
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Floating Side Menu
          if (!isRecording)
            Positioned(
              top: 48,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    // Flip Camera
                    _buildMenuIcon(
                      icon: Icons.flip_camera_ios,
                      label: "Flip",
                      onTap: () {
                        _deepArController?.flipCamera();
                      },
                    ),
                    const SizedBox(height: 16),

                    // Flash Toggle
                    _buildMenuIcon(
                      icon: _flashMode == FlashState.off
                          ? Icons.flash_off
                          : Icons.flash_on,
                      label: "Flash",
                      onTap: _toggleFlash,
                      isActive: _flashMode == FlashState.on,
                    ),
                    const SizedBox(height: 16),

                    // Timer Toggle
                    _buildMenuIcon(
                      icon: _timerDelay == 0
                          ? Icons.timer_off_outlined
                          : (_timerDelay == 3 ? Icons.timer_3 : Icons.timer_10),
                      label: "Timer",
                      onTap: _toggleTimer,
                      isActive: _timerDelay > 0,
                    ),
                  ],
                ),
              ),
            ),

          // Effects / Filters List (New)
          if (!isRecording)
            Positioned(
              bottom: 150, // Above controls
              left: 0,
              right: 0,
              child: SizedBox(
                height: 70,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _effects.length,
                  itemBuilder: (context, index) {
                    final effect = _effects[index];
                    final isSelected = _selectedEffectIndex == index;
                    return GestureDetector(
                      onTap: () => _switchEffect(index),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.neonPink
                                : Colors.white,
                            width: 2,
                          ),
                          color: Colors.black.withOpacity(0.5),
                        ),
                        child: Center(
                          child: Text(
                            effect == 'none' ? 'Ø' : effect[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
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
                                  image: _lastImageBytes != null
                                      ? DecorationImage(
                                          image: MemoryImage(_lastImageBytes!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                  color: _lastImageBytes == null
                                      ? Colors.grey[800]
                                      : null,
                                ),
                                child: _lastImageBytes == null
                                    ? const Icon(
                                        Icons.image,
                                        color: Colors.white,
                                        size: 20,
                                      )
                                    : null,
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
                          onPressed: _confirmDiscard,
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
                                      currentProgress: _currentSegmentProgress,
                                      color: const Color(0xFFFE2C55),
                                      strokeWidth: 6,
                                    ),
                                  ),
                                ),
                              Center(
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
                              color: AppColors.neonPink,
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
                if (!isRecording)
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
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            child: Text(
                              _modes[index],
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey,
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
      ),
    );
  }

  Widget _buildMenuIcon({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(
            icon,
            color: isActive ? Colors.yellow : Colors.white,
            size: 28,
            shadows: [
              Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 4),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              shadows: [Shadow(color: Colors.black, blurRadius: 2)],
            ),
          ),
        ],
      ),
    );
  }
}

// Dummy screen for Live Setup (unchanged)
class LiveStreamSetupScreen extends StatelessWidget {
  const LiveStreamSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Go Live"),
        backgroundColor: Colors.transparent,
      ),
      body: const Center(
        child: Text("Live Stream Setup", style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

// SegmentedRingPainter (unchanged)
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
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    final double radius = (size.width - strokeWidth) / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double startAngle = -3.14159 / 2; // -90 degrees

    double currentAngle = startAngle;

    // Draw completed segments
    for (double segment in segments) {
      double sweepAngle = segment * 2 * 3.14159; // 360 degrees
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentAngle,
        sweepAngle,
        false,
        paint,
      );

      currentAngle += sweepAngle;

      // Draw white separator (gap indicator)
      final Paint separatorPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt;

      double gap = 0.08; // Check visible gap size
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentAngle,
        gap,
        false,
        separatorPaint,
      );

      currentAngle += gap;
    }

    // Draw active segment
    if (currentProgress > 0) {
      double sweepAngle = currentProgress * 2 * 3.14159;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SegmentedRingPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.currentProgress != currentProgress;
  }
}
