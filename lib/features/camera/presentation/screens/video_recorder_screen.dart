import 'dart:async';
import 'dart:io';
import 'package:deepar_flutter_plus/deepar_flutter_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart'; // Added for duration check
import 'preview_screen.dart';
import 'package:test_flutter/core/theme/app_theme.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/sound_pill_widget.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';

import '../../data/models/sound_model.dart';
import 'sound_selection_screen.dart';
import '../../data/services/deepar_service.dart';
import '../../../live/presentation/screens/live_stream_setup_screen.dart';
import 'package:test_flutter/core/widgets/neon_border_container.dart';
import '../widgets/glass_action_button.dart';
import 'dart:ui'; // For ImageFilter
import '../../../auth/presentation/providers/auth_provider.dart';

class VideoRecorderScreen extends ConsumerStatefulWidget {
  final List<XFile> initialFiles;
  final String? draftId;
  final Sound? initialSound;

  const VideoRecorderScreen({
    super.key,
    this.initialFiles = const [],
    this.draftId,
    this.initialSound,
  });

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
  int _selectedModeIndex = 1; // 0: Photo, 1: 15s, 2: 60s, 3: Live (if allowed)

  // Effects - Map of display name to effect data (path and preview)
  final Map<String, Map<String, String>> _effects = {
    'None': <String, String>{
      'path': 'none',
      'preview': '', // No preview for None
    },
    'Flower Face': <String, String>{
      'path': 'Flower_Face/flower_face',
      'preview': 'assets/deepar/Flower_Face/preview.png',
    },
    'Vendetta Mask': <String, String>{
      'path': 'Vendetta_Mask/Vendetta_Mask',
      'preview': 'assets/deepar/Vendetta_Mask/preview.png',
    },
    'Fire Effect': <String, String>{
      'path': 'Fire_Effect/Fire_Effect',
      'preview': 'assets/deepar/Fire_Effect/preview.png',
    },
  };

  String _selectedEffectName = 'None';

  final List<XFile> _recordedFiles = [];
  Timer? _timer;
  final List<double> _segments = [];
  double _currentSegmentProgress = 0.0;
  int _maxDuration = 15;
  bool isPaused = false;
  bool _isProcessing = false;

  // New State for Side Menu
  FlashState _flashMode = FlashState.off;
  int _timerDelay = 0; // 0, 3, 10 seconds
  int _countdown = 0; // Current countdown value

  // Media Picker State
  Uint8List? _lastImageBytes;

  // Sound
  Sound? _selectedSound;

  // Computed list of available modes based on user permissions
  List<String> get _availableModes {
    final user = ref.read(authControllerProvider).value;
    final baseModes = ['Photo', '15s', '60s', 'Live'];

    // Remove 'Live' mode if user doesn't have permission
    if (user == null || !user.allowLive) {
      return baseModes.where((mode) => mode != 'Live').toList();
    }
    return baseModes;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialSound != null) {
      _selectedSound = widget.initialSound;
    }
    _initializeDeepAr();
    _fetchLastImage();
    if (widget.initialFiles.isNotEmpty) {
      // Delay loading to avoid resource contention with PreviewScreen (especially audio session)
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _loadInitialFiles();
      });
    }
  }

  Future<void> _loadInitialFiles() async {
    List<XFile> loadedFiles = [];
    List<double> fileDurations = [];
    double totalDuration = 0;

    // 1. Gather all files and durations
    for (final xFile in widget.initialFiles) {
      final file = File(xFile.path);
      if (!file.existsSync()) continue;

      final controller = VideoPlayerController.file(file);
      try {
        await controller.initialize();
        final duration = controller.value.duration;
        final durationSec = duration.inMilliseconds / 1000.0;

        loadedFiles.add(xFile);
        fileDurations.add(durationSec);
        totalDuration += durationSec;
      } catch (e) {
        debugPrint("Error loading file duration: $e");
      } finally {
        await controller.dispose();
      }
    }

    if (loadedFiles.length < widget.initialFiles.length) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Warning: ${widget.initialFiles.length - loadedFiles.length} segment(s) could not be loaded.",
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    if (!mounted || loadedFiles.isEmpty) return;

    // 2. Determine Mode based on TOTAL duration
    int newMaxDuration = 15;
    int newModeIndex = 1; // 15s

    if (totalDuration > 15.0) {
      newMaxDuration = 60;
      newModeIndex = 2; // 60s
    }

    // 3. Calculate segments
    List<double> newSegments = [];
    for (final dur in fileDurations) {
      double progress = dur / newMaxDuration;
      // if (progress > 1.0) progress = 1.0; // Don't clip individual, total might overflow slightly?
      newSegments.add(progress);
    }

    setState(() {
      _recordedFiles.addAll(loadedFiles);
      _maxDuration = newMaxDuration;
      _selectedModeIndex = newModeIndex;
      _segments.addAll(newSegments);
      isPaused = true;
    });

    // Restore Music State for Resume
    if (_selectedSound != null) {
      try {
        String url = _selectedSound!.url;
        Source? source;
        if (url.startsWith('assets/')) {
          source = AssetSource(url.substring(7));
        } else {
          source = UrlSource(url);
        }

        // Prepare not play
        await _audioPlayer.setSource(source);
        // Seek to current total duration
        int seekMillis = (totalDuration * 1000).toInt();
        await _audioPlayer.seek(Duration(milliseconds: seekMillis));
      } catch (e) {
        debugPrint("Error restoring audio state: $e");
      }
    }
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
    // Ensure DeepAR is destroyed when leaving screen (e.g. back button)
    _deepArController?.destroy();
    super.dispose();
  }

  void _onModeChanged(int index) async {
    if (isRecording || isPaused) return;
    setState(() {
      _selectedModeIndex = index;
    });

    if (_availableModes[index] == 'Live') {
      // Stop DeepAR camera before pushing to LiveStreamSetupScreen
      if (_deepArController != null) {
        try {
          await _deepArController!.destroy();
        } catch (e) {
          debugPrint("DeepAR destroy error: $e");
        }
        _deepArController = null;
        setState(() {
          _isDeepArInitialized = false;
        });
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LiveStreamSetupScreen()),
        result: 'live_mode',
      );
      return;
    }

    if (_availableModes[index] == '15s') {
      _maxDuration = 15;
    } else if (_availableModes[index] == '60s') {
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

  void _switchEffect(String effectName) async {
    if (_deepArController == null) return;
    setState(() {
      _selectedEffectName = effectName;
    });

    final effectData = _effects[effectName];
    if (effectData == null) return;

    final effectPath = effectData['path'];
    if (effectPath == null) return;

    if (effectPath == 'none') {
      // Reinitialize controller to clear effect
      await _reinitializeDeepAr();
    } else {
      String assetPath = "assets/deepar/$effectPath.deepar";
      print(assetPath);
      try {
        final File file = await _copyAssetToFile(assetPath);
        print(file.path);
        _deepArController?.switchEffect(file.path);
      } catch (e) {
        debugPrint("Error loading effect: $e");
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error loading effect: $e")));
      }
    }
  }

  Future<void> _reinitializeDeepAr() async {
    // Clear current controller
    setState(() {
      _deepArController = null;
      _isDeepArInitialized = false;
    });

    // Small delay to ensure cleanup
    await Future.delayed(const Duration(milliseconds: 100));

    // Reinitialize
    await _initializeDeepAr();
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

    // Optimistic UI Update: Immediately show "Paused" state
    setState(() {
      isRecording = false;
      isPaused = true;
      _isProcessing = true; // Block further actions until save completes
    });

    try {
      // Stop Audio IMMEDIATELY so user doesn't hear it continuing during save
      await _audioPlayer.pause();

      // Background: Stop recording and save file
      final dynamic result = await _deepArController!.stopVideoRecording();

      // Pause Music concurrently or after
      // await _audioPlayer.pause(); // Moved up

      File? file;
      if (result is File) {
        file = result;
      } else if (result is String) {
        file = File(result);
      }

      if (!mounted) return;

      setState(() {
        if (file != null) {
          debugPrint("Recorder: Segment saved. Path: ${file.path}");
          _recordedFiles.add(XFile(file.path));
          _segments.add(_currentSegmentProgress);
        } else {
          debugPrint("Recorder: Stop returned NULL file!");
          // If save failed, we might want to revert UI??
          // For now, let's keep it paused but with no new segment added,
          // or we could show error.
        }
        _currentSegmentProgress = 0.0;
        _isProcessing = false; // Re-enable actions
      });
    } catch (e) {
      debugPrint("Error pausing recording: $e");
      if (mounted) {
        setState(() {
          _isProcessing = false;
          // Optionally revert state if critical failure
        });
      }
    }
  }

  void _resumeTimer() async {
    debugPrint("Recorder: Resuming... Starting new segment (DeepAR).");
    if (_deepArController == null) return;

    await _deepArController!.startVideoRecording();

    // Resume Music
    if (_selectedSound != null) {
      if (_audioPlayer.state == PlayerState.paused) {
        await _audioPlayer.resume();
      } else {
        // If not paused (e.g. stopped/initial), play from correct position
        double totalProgress = _segments.fold(0.0, (sum, seg) => sum + seg);
        int seekMillis = (totalProgress * _maxDuration * 1000).toInt();

        String url = _selectedSound!.url;
        Source source;
        if (url.startsWith('assets/')) {
          source = AssetSource(url.substring(7));
        } else {
          source = UrlSource(url);
        }
        await _audioPlayer.play(
          source,
          position: Duration(milliseconds: seekMillis),
        );
      }
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
    if (_recordedFiles.isEmpty || _isProcessing) return;

    debugPrint("Recorder: Discarding last segment.");

    final lastFile = File(_recordedFiles.last.path);
    // final lastSegmentProgress = _segments.isNotEmpty ? _segments.last : 0.0; // Unused

    // Optimistic UI Update first
    setState(() {
      _isProcessing = true;
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

    try {
      // Delete file in background
      if (await lastFile.exists()) {
        await lastFile.delete();
        debugPrint("Recorder: Deleted segment file: ${lastFile.path}");
      }

      // Reset audio position to new end
      if (_selectedSound != null && _recordedFiles.isNotEmpty) {
        double totalProgress = _segments.fold(0.0, (sum, seg) => sum + seg);
        int seekMillis = (totalProgress * _maxDuration * 1000).toInt();
        await _audioPlayer.seek(Duration(milliseconds: seekMillis));
      } else if (_selectedSound != null && _recordedFiles.isEmpty) {
        await _audioPlayer.seek(Duration.zero);
      }
    } catch (e) {
      debugPrint("Error discarding segment: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
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

    // Calculate total duration
    double totalProgress = _segments.fold(0.0, (sum, seg) => sum + seg);
    // If we just stopped a recording, add its progress (which wasn't added to _segments yet)
    // Actually, in the logic above:
    // We added the file to _recordedFiles, but we didn't explicitly add _currentSegmentProgress to _segments
    // because we are about to clear it.
    // However, if we fail validation, we MUST add it to _segments to keep state consistent?
    // Or just calculate for validation now.
    // If the last block executed (isRecording was true), we have a new file.
    // But _segments was NOT updated in that block (lines 313-325).
    // So totalProgress currently only has OLD segments.
    // We need to account for the just-finished segment.

    // Wait, _currentSegmentProgress is still valid here from the timer?
    // Yes.

    double currentDuration = totalProgress * _maxDuration;
    if (isRecording) {
      currentDuration += (_currentSegmentProgress * _maxDuration);
    }

    if (currentDuration < 1.0) {
      if (mounted) {
        setState(() {
          // We finished the "recording" action, but we are essentially "pausing" now
          // because we are not navigating.
          // We need to ensure the LAST file is added to _segments if we want to keep it?
          // The block above added it to _recordedFiles.
          // We should add its progress to _segments too, so if we Resume, it's counted.
          if (isRecording) {
            // If we just transitioned from recording
            _segments.add(_currentSegmentProgress);
            isPaused = true;
            isRecording = false;
            _currentSegmentProgress = 0.0;
          } else {
            // If we were already paused and just hit check
            // State is already clean.
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Recording must be at least 1 second")),
        );
      }
      return;
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
            draftId: widget.draftId,
            isFromGallery: false,
          ),
        ),
      );
      if (soundToPass != null) {}
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No video recorded!")));
    }
  }

  void _recordVideo() async {
    if (_isProcessing) return;
    if (_deepArController == null || !_isDeepArInitialized) return;

    // Photo Mode
    if (_availableModes[_selectedModeIndex] == 'Photo') {
      final File file = await _deepArController!.takeScreenshot();
      if (file != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PreviewScreen(
              files: [XFile(file.path)],
              isVideo: false,
              isFromGallery: false,
            ),
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

          if (_countdown > 1) {
            _audioPlayer.play(AssetSource('sounds/beep.wav'));
          } else if (_countdown == 1) {
            _audioPlayer.play(AssetSource('sounds/start_record.wav'));
          }

          if (_countdown <= 0) {
            timer.cancel();
            if (mounted) startAction();
          }
        });
      } else {
        // Immediate
        // Immediate
        startAction();
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

      if (isVideo) {
        VideoPlayerController? tempController;
        try {
          // Check duration
          tempController = VideoPlayerController.file(File(media.path));
          await tempController.initialize();

          if (tempController.value.duration.inSeconds > 60) {
            // Needs trimming
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "Video longer than 60s. Trimming to first 60 seconds...",
                  ),
                ),
              );
            }

            final tempDir = await getTemporaryDirectory();
            final outputPath =
                '${tempDir.path}/trimmed_${DateTime.now().millisecondsSinceEpoch}.mp4';

            // -ss 0 -i input -t 60 -c copy output
            // Using -c copy is fast and prevents re-encoding quality loss here.
            final command =
                '-ss 0 -i "${media.path}" -t 60 -c copy "$outputPath"';

            await FFmpegKit.execute(command);

            // Use the trimmed file
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PreviewScreen(
                  files: [XFile(outputPath)],
                  isVideo: true,
                  isFromGallery: true,
                ),
              ),
            );
          } else {
            // Duration OK
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PreviewScreen(
                  files: [media],
                  isVideo: true,
                  isFromGallery: true,
                ),
              ),
            );
          }
        } catch (e) {
          debugPrint("Error checking/trimming video: $e");
          // Fallback to original
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PreviewScreen(
                files: [media],
                isVideo: true,
                isFromGallery: true,
              ),
            ),
          );
        } finally {
          tempController?.dispose();
        }
      } else {
        // Image
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PreviewScreen(
              files: [media],
              isVideo: false,
              isFromGallery: true,
            ),
          ),
        );
      }
    }
  }

  void _selectSound() async {
    if (_recordedFiles.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Cannot change sound after recording has started"),
        ),
      );
      return;
    }

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
          Positioned(
            top: 48,
            left: 16,
            child: IgnorePointer(
              ignoring: isRecording,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isRecording ? 0.0 : 1.0,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),

          // Select Sound
          // Top Sound Selector
          Positioned(
            top: 48,
            left: 0,
            right: 0,
            child: SoundPillWidget(
              selectedSound: _selectedSound,
              onTap: _selectSound,
              onClear: () {
                if (_recordedFiles.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Cannot change sound after recording has started",
                      ),
                    ),
                  );
                  return;
                }
                setState(() {
                  _selectedSound = null;
                });
              },
              isRecording: isRecording,
              hasRecordedFiles: _recordedFiles.isNotEmpty,
            ),
          ),

          // Floating Side Menu
          // Floating Side Menu
          Positioned(
            top: 100, // Moved down slightly
            right: 16,
            child: IgnorePointer(
              ignoring: isRecording,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isRecording ? 0.0 : 1.0,
                child: Column(
                  children: [
                    // Flip Camera
                    GlassActionButton(
                      icon: Icons.flip_camera_ios,
                      label: "Flip",
                      onTap: () {
                        _deepArController?.flipCamera();
                      },
                    ),
                    const SizedBox(height: 16),

                    // Flash Toggle
                    GlassActionButton(
                      icon: _flashMode == FlashState.off
                          ? Icons.flash_off
                          : Icons.flash_on,
                      label: "Flash",
                      onTap: _toggleFlash,
                      isActive: _flashMode == FlashState.on,
                      activeColor: AppColors.neonCyan,
                    ),
                    const SizedBox(height: 16),

                    // Timer Toggle
                    GlassActionButton(
                      icon: _timerDelay == 0
                          ? Icons.timer_off_outlined
                          : (_timerDelay == 3 ? Icons.timer_3 : Icons.timer_10),
                      label: "Timer",
                      onTap: _toggleTimer,
                      isActive: _timerDelay > 0,
                      activeColor: AppColors.neonPink,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Effects / Filters List (New)
          // Effects / Filters List (New)
          Positioned(
            bottom: 150, // Above controls
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: isRecording,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isRecording ? 0.0 : 1.0,
                child: SizedBox(
                  height: 70,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _effects.length,
                    itemBuilder: (context, index) {
                      final effectName = _effects.keys.elementAt(index);
                      final effectData = _effects[effectName]!;
                      final previewPath = effectData['preview'] ?? '';
                      final isSelected = _selectedEffectName == effectName;
                      return GestureDetector(
                        onTap: () => _switchEffect(effectName),
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors
                                        .neonCyan // Neon Border
                                  : Colors.white.withOpacity(0.5),
                              width: isSelected ? 3 : 2,
                            ),
                            boxShadow: isSelected
                                ? [
                                    const BoxShadow(
                                      color: AppColors.neonCyan,
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : [],
                            color: Colors.black.withOpacity(0.5),
                          ),
                          child: ClipOval(
                            child: previewPath.isNotEmpty
                                ? Image.asset(
                                    previewPath,
                                    fit: BoxFit.cover,
                                    width: 60,
                                    height: 60,
                                    errorBuilder: (context, error, stackTrace) {
                                      // Fallback to text if image fails to load
                                      return Center(
                                        child: Text(
                                          effectName[0].toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : Center(
                                    child: Text(
                                      'Ø',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
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
                              SizedBox(
                                width: 36,
                                height: 36,
                                child: NeonBorderContainer(
                                  borderRadius: 8,
                                  padding: EdgeInsets.zero,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      image: _lastImageBytes != null
                                          ? DecorationImage(
                                              image: MemoryImage(
                                                _lastImageBytes!,
                                              ),
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
                                        : AppColors.neonPink.withOpacity(
                                            0.5,
                                          ), // Pink Ring
                                    width: 6,
                                  ),
                                  boxShadow: isRecording
                                      ? [] // Glow handled by painter or inner button
                                      : [
                                          BoxShadow(
                                            color: AppColors.neonPink
                                                .withOpacity(0.2),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                ),
                              ),
                              if (isRecording || isPaused)
                                SizedBox(
                                  height: 80,
                                  width: 80,
                                  child: CustomPaint(
                                    painter: SegmentedRingPainter(
                                      segments: List.from(_segments),
                                      currentProgress: _currentSegmentProgress,
                                      color:
                                          AppColors.neonPink, // Pink Progress
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
                                    color: AppColors.neonPink, // Pink Button
                                    borderRadius: BorderRadius.circular(
                                      isRecording ? 6 : 30,
                                    ),
                                    boxShadow: [
                                      const BoxShadow(
                                        color: AppColors.neonPink,
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
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
                              color: AppColors.neonCyan, // Cyan Checkmark
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.neonCyan,
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.black, // Dark icon for contrast
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
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: SizedBox(
                    height: (!isRecording && !isPaused) ? 30 : 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: (!isRecording && !isPaused) ? 1.0 : 0.0,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        shrinkWrap: true,
                        itemCount: _availableModes.length,
                        itemBuilder: (context, index) {
                          bool isSelected = _selectedModeIndex == index;
                          return GestureDetector(
                            onTap: () => _onModeChanged(index),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                              ),
                              child: Text(
                                _availableModes[index],
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.5),
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 14,
                                  shadows: isSelected
                                      ? [
                                          const Shadow(
                                            color: AppColors.neonCyan,
                                            blurRadius: 8,
                                          ),
                                        ]
                                      : [],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
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
