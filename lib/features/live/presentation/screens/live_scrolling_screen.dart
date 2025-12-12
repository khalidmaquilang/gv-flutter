import 'package:flutter/material.dart';
import '../../data/models/live_stream_model.dart';
import 'live_stream_screen.dart';

class LiveScrollingScreen extends StatefulWidget {
  final List<LiveStream> streams;
  final int initialIndex;

  const LiveScrollingScreen({
    super.key,
    required this.streams,
    required this.initialIndex,
  });

  @override
  State<LiveScrollingScreen> createState() => _LiveScrollingScreenState();
}

class _LiveScrollingScreenState extends State<LiveScrollingScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: _pageController,
        itemCount: widget.streams.length,
        itemBuilder: (context, index) {
          final stream = widget.streams[index];
          return LiveStreamScreen(
            isBroadcaster: false,
            channelId: stream.channelId,
          );
        },
      ),
    );
  }
}
