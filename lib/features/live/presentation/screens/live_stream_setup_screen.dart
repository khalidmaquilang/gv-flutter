import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:test_flutter/core/theme/app_theme.dart';
import 'live_stream_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/feed/presentation/providers/feed_audio_provider.dart';
import '../../data/services/live_service.dart';

class LiveStreamSetupScreen extends ConsumerStatefulWidget {
  const LiveStreamSetupScreen({super.key});

  @override
  ConsumerState<LiveStreamSetupScreen> createState() =>
      _LiveStreamSetupScreenState();
}

class _LiveStreamSetupScreenState extends ConsumerState<LiveStreamSetupScreen> {
  final TextEditingController _titleController = TextEditingController();
  CameraController? _cameraController;
  bool _isPermissionGranted = false;
  bool _isGoingToLive = false;
  bool _isCreatingLive = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      // Wait for DeepAR to release camera (VideoRecorderScreen disposal overlap)
      await Future.delayed(const Duration(milliseconds: 500));

      // Request permissions
      Map<Permission, PermissionStatus> statuses = await [
        Permission.microphone,
        Permission.camera,
      ].request();

      if (statuses[Permission.camera] != PermissionStatus.granted ||
          statuses[Permission.microphone] != PermissionStatus.granted) {
        if (mounted) {
          setState(() {
            _errorMessage = "Camera/Mic permissions required.";
          });
        }
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _errorMessage = "No cameras found.";
          });
        }
        return;
      }

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false, // Audio not needed for setup preview
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isPermissionGranted = true;
        });
      }
    } catch (e) {
      debugPrint("Live Setup Camera Error: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to start camera: $e";
        });
      }
    }
  }

  Future<void> _startLiveStream() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title for your stream')),
      );
      return;
    }

    if (_isCreatingLive) return; // Prevent multiple presses

    setState(() {
      _isCreatingLive = true;
    });

    _isGoingToLive = true;

    // Create live stream via API
    final liveService = LiveService();
    final result = await liveService.createLive(_titleController.text.trim());

    if (result == null ||
        result['id'] == null ||
        result['stream_key'] == null) {
      if (mounted) {
        setState(() {
          _isCreatingLive = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create live stream')),
        );
      }
      _isGoingToLive = false;
      return;
    }

    final liveId = result['id'].toString();
    final streamKey = result['stream_key'].toString();

    // Dispose local controller before navigating to release camera
    if (_cameraController != null) {
      await _cameraController!.dispose();
      _cameraController = null;
    }

    // Add delay to allow Xiaomi/Android OS to fully release camera resource
    // before Zego tries to acquire it. This fixes the Xiaomi specific crash.
    await Future.delayed(const Duration(milliseconds: 1000));

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => LiveStreamScreen(
          isBroadcaster: true,
          channelId: streamKey,
          liveId: liveId,
          liveTitle: _titleController.text.trim(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // If we are NOT going to live stream (e.g. back button), restore feed audio
    // Check mounted to ensure widget is still in tree before using ref
    if (!_isGoingToLive && mounted) {
      try {
        ref.read(isFeedAudioEnabledProvider.notifier).state = true;
      } catch (e) {
        debugPrint('Error restoring feed audio: $e');
      }
    }

    _titleController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset:
          false, // Prevents video distortion when keyboard shows
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Camera Preview
          if (_errorMessage != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.neonPink,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _initCamera,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text("Retry"),
                  ),
                ],
              ),
            )
          else if (_isPermissionGranted &&
              _cameraController != null &&
              _cameraController!.value.isInitialized)
            // Use FittedBox to prevent stretching
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize!.height,
                  height: _cameraController!.value.previewSize!.width,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),

          // Overlay Content
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          // Restore feed audio before popping
                          if (!_isGoingToLive) {
                            ref
                                    .read(isFeedAudioEnabledProvider.notifier)
                                    .state =
                                true;
                          }
                          Navigator.of(context).pop();
                        },
                      ),
                      const Text(
                        "LIVE Setup",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 40), // Balance close button
                    ],
                  ),
                ),

                const Spacer(),

                // Setup Card
                Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add a Title regarding your LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _titleController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Enter title here...',
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.2),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isCreatingLive
                                ? null
                                : _startLiveStream,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.neonPink,
                              disabledBackgroundColor: AppColors.neonPink
                                  .withOpacity(0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: _isCreatingLive
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Go LIVE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
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
