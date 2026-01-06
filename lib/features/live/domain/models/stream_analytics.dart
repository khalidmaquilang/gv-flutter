class StreamAnalytics {
  final Duration streamDuration;
  final int totalViews;
  final List<GifterStats> topGifters;
  final DateTime startTime;
  final DateTime endTime;

  const StreamAnalytics({
    required this.streamDuration,
    required this.totalViews,
    required this.topGifters,
    required this.startTime,
    required this.endTime,
  });

  // Helper to get formatted duration string (HH:MM:SS)
  String get formattedDuration {
    final hours = streamDuration.inHours;
    final minutes = streamDuration.inMinutes.remainder(60);
    final seconds = streamDuration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class GifterStats {
  final String userId;
  final String userName;
  final int totalGiftsValue; // Total value in coins
  final int giftCount; // Number of gifts sent

  const GifterStats({
    required this.userId,
    required this.userName,
    required this.totalGiftsValue,
    required this.giftCount,
  });

  // For sorting gifters by total value
  int compareTo(GifterStats other) {
    return other.totalGiftsValue.compareTo(totalGiftsValue);
  }
}
