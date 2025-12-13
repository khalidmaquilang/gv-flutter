import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:test_flutter/core/theme/app_theme.dart';
import 'package:test_flutter/core/constants/api_constants.dart';
import 'live_stream_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/feed/presentation/providers/feed_audio_provider.dart';

class LiveStreamSetupScreen extends ConsumerStatefulWidget {
  const LiveStreamSetupScreen({super.key});

  @override
  ConsumerState<LiveStreamSetupScreen> createState() =>
      _LiveStreamSetupScreenState();
}

class _LiveStreamSetupScreenState extends ConsumerState<LiveStreamSetupScreen> {
  final TextEditingController _titleController = TextEditingController();
  late RtcEngine _engine;
  bool _isPermissionGranted = false;
  bool _isGoingToLive = false;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    // Wait for DeepAR to release camera (VideoRecorderScreen disposal overlap)
    await Future.delayed(const Duration(milliseconds: 500));

    // Request permissions
    await [Permission.microphone, Permission.camera].request();

    // Create & Init Engine
    _engine = createAgoraRtcEngine();
    await _engine.initialize(
      const RtcEngineContext(
        appId: ApiConstants.agoraAppId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );

    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine.enableVideo();
    await _engine.startPreview();

    if (mounted) {
      setState(() {
        _isPermissionGranted = true;
      });
    }
  }

  void _startLiveStream() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title for your stream')),
      );
      return;
    }

    // Navigate and Dispose local preview engine
    _isGoingToLive = true;
    try {
      await _engine.leaveChannel();
      await _engine.release();
    } catch (e) {
      debugPrint("Error releasing setup engine: $e");
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => LiveStreamScreen(
          isBroadcaster: true,
          channelId: ApiConstants.fixedTestChannelId,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    // Engine might be released in _startLiveStream, check validity or try catch if needed
    // But safely:
    // _engine.release(); // verify if already released?
    // Simplified: Just release if not navigating?
    // Since we await release in startLiveStream, standard dispose is tricky.
    // Let's rely on standard lifecycle if user backs out.
    // If we pop, dispose is called.
    // If we pushReplacement, dispose is called.
    // So we should release here only if we didn't already.
    // Making it simple: Re-init in next screen implies we must release here.
    try {
      _engine.leaveChannel();
      _engine.release();
    } catch (e) {
      // already released
    }

    // If we are NOT going to live stream (e.g. back button), restore feed audio
    if (!_isGoingToLive) {
      // We need to use ProviderContainer or similar if context is not valid,
      // but ref.read is valid in dispose.
      ref.read(isFeedAudioEnabledProvider.notifier).state = true;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Camera Preview
          if (_isPermissionGranted)
            AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: _engine,
                canvas: const VideoCanvas(uid: 0),
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
                        onPressed: () => Navigator.of(context).pop(),
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
                Container(
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
                          onPressed: _startLiveStream,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.neonPink,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: const Text(
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
