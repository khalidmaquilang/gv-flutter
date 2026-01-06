import 'package:flutter/material.dart';
import 'package:test_flutter/features/live/domain/models/stream_analytics.dart';
import 'package:test_flutter/features/live/domain/models/gift_item.dart';

class StreamAnalyticsManager {
  static final StreamAnalyticsManager _instance =
      StreamAnalyticsManager._internal();
  factory StreamAnalyticsManager() => _instance;
  StreamAnalyticsManager._internal();

  // Tracking state
  DateTime? _startTime;
  final Set<String> _uniqueViewers = {};
  final Map<String, _GifterData> _gifterMap = {};
  bool _isTracking = false;

  /// Start tracking stream analytics
  void startTracking({bool addMockData = true}) {
    _startTime = DateTime.now();
    _uniqueViewers.clear();
    _gifterMap.clear();
    _isTracking = true;

    // Add mock data for testing
    if (addMockData) {
      _addMockGiftData();
    }

    debugPrint('📊 Stream analytics tracking started');
  }

  /// Add mock gift data for testing
  void _addMockGiftData() {
    // Mock gifter 1 - Top gifter
    _gifterMap['user_001'] = _GifterData(
      userName: 'AlexTheGreat',
      totalValue: 2500,
      giftCount: 12,
    );

    // Mock gifter 2 - Second place
    _gifterMap['user_002'] = _GifterData(
      userName: 'BellaStarlight',
      totalValue: 1800,
      giftCount: 9,
    );

    // Mock gifter 3 - Third place
    _gifterMap['user_003'] = _GifterData(
      userName: 'CharlieVibes',
      totalValue: 1200,
      giftCount: 6,
    );

    // Mock viewers
    _uniqueViewers.addAll([
      'user_001',
      'user_002',
      'user_003',
      'viewer_001',
      'viewer_002',
      'viewer_003',
      'viewer_004',
      'viewer_005',
    ]);

    debugPrint('✨ Added mock gift data for testing');
  }

  /// Record a viewer joining the stream
  void recordViewerJoin(String userId) {
    if (!_isTracking) return;
    _uniqueViewers.add(userId);
  }

  /// Record a gift sent during the stream
  void recordGift(GiftMessage giftMessage) {
    if (!_isTracking) return;

    final userId = giftMessage.senderUserId;
    final userName = giftMessage.senderUserName;
    final giftValue = giftMessage.gift.price * giftMessage.count;

    if (_gifterMap.containsKey(userId)) {
      _gifterMap[userId]!.totalValue += giftValue;
      _gifterMap[userId]!.giftCount += giftMessage.count;
    } else {
      _gifterMap[userId] = _GifterData(
        userName: userName,
        totalValue: giftValue,
        giftCount: giftMessage.count,
      );
    }
  }

  /// Stop tracking and return analytics summary
  StreamAnalytics stopTracking() {
    if (!_isTracking || _startTime == null) {
      debugPrint('⚠️ Attempted to stop tracking when not started');
      return StreamAnalytics(
        streamDuration: Duration.zero,
        totalViews: 0,
        topGifters: [],
        startTime: DateTime.now(),
        endTime: DateTime.now(),
      );
    }

    final endTime = DateTime.now();
    final duration = endTime.difference(_startTime!);

    // Get top 3 gifters sorted by total value
    final allGifters = _gifterMap.entries
        .map(
          (e) => GifterStats(
            userId: e.key,
            userName: e.value.userName,
            totalGiftsValue: e.value.totalValue,
            giftCount: e.value.giftCount,
          ),
        )
        .toList();

    allGifters.sort((a, b) => b.totalGiftsValue.compareTo(a.totalGiftsValue));
    final topGifters = allGifters.take(3).toList();

    _isTracking = false;

    debugPrint('📊 Stream analytics tracking stopped');
    debugPrint(
      '   Duration: ${duration.inMinutes}m ${duration.inSeconds % 60}s',
    );
    debugPrint('   Total Views: ${_uniqueViewers.length}');
    debugPrint('   Top Gifters: ${topGifters.length}');

    return StreamAnalytics(
      streamDuration: duration,
      totalViews: _uniqueViewers.length,
      topGifters: topGifters,
      startTime: _startTime!,
      endTime: endTime,
    );
  }

  /// Check if currently tracking
  bool get isTracking => _isTracking;

  /// Reset all tracking data
  void reset() {
    _startTime = null;
    _uniqueViewers.clear();
    _gifterMap.clear();
    _isTracking = false;
  }
}

// Internal class to track gifter data
class _GifterData {
  final String userName;
  int totalValue;
  int giftCount;

  _GifterData({
    required this.userName,
    required this.totalValue,
    required this.giftCount,
  });
}
