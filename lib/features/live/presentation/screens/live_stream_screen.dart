import 'package:flutter/material.dart';
import '../../data/services/live_service.dart';

class LiveStreamScreen extends StatefulWidget {
  final bool isBroadcaster;
  final String channelId;

  const LiveStreamScreen({
    super.key,
    required this.isBroadcaster,
    required this.channelId,
  });

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  final _liveService = LiveService(); // Should use provider
  bool _joined = false;
  int? _remoteUid;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    // Mock init
    // await _liveService.initialize(...);
    // await _liveService.joinChannel(widget.channelId, "TOKEN", widget.isBroadcaster);
    setState(() {
      _joined = true;
    });
  }

  @override
  void dispose() {
    _liveService.leaveChannel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: _joined
                ? Text(
                    widget.isBroadcaster ? "Broadcasting..." : "Watching...",
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  )
                : const CircularProgressIndicator(),
          ),
          if (widget.isBroadcaster)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 40),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

          // Live Chat Overlay
          Positioned(
            bottom: 100,
            left: 16,
            height: 200,
            width: 250,
            child: ListView(
              children: const [
                Text("User1: Hello!", style: TextStyle(color: Colors.white)),
                Text(
                  "User2: Cool stream!",
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),

          // Gift Button (Audience)
          if (!widget.isBroadcaster)
            Positioned(
              bottom: 30,
              right: 16,
              child: IconButton(
                icon: const Icon(
                  Icons.card_giftcard,
                  color: Color(0xFFFE2C55),
                  size: 40,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text("Gift Sent!")));
                },
              ),
            ),
        ],
      ),
    );
  }
}
