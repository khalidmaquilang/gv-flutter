import 'package:flutter/foundation.dart';

/// PK Battle state
enum PKBattleState {
  idle, // Not in PK
  inviting, // Sent/received invitation
  preparing, // Accepted, preparing streams
  active, // PK in progress
  ending, // PK ending
}

/// PK Battle information
class PKBattleInfo {
  final String pkId;
  final String hostAId;
  final String hostAName;
  final String hostBId;
  final String hostBName;
  final PKBattleState state;
  final DateTime? startTime;
  final int durationSeconds;
  final Map<String, String> votes; // userId -> hostId voted for

  const PKBattleInfo({
    required this.pkId,
    required this.hostAId,
    required this.hostAName,
    required this.hostBId,
    required this.hostBName,
    required this.state,
    this.startTime,
    this.durationSeconds = 300, // 5 minutes default
    this.votes = const {},
  });

  // Stream IDs for mixing
  String get mixedStreamId => 'pk_${pkId}_mixed';
  String get hostAStreamId => '${hostAId}_main';
  String get hostBStreamId => '${hostBId}_main';

  // Vote counts
  int get hostAVotes => votes.values.where((v) => v == hostAId).length;
  int get hostBVotes => votes.values.where((v) => v == hostBId).length;

  // Time remaining
  int? get timeRemaining {
    if (startTime == null) return null;
    final elapsed = DateTime.now().difference(startTime!).inSeconds;
    final remaining = durationSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  // Is PK expired
  bool get isExpired {
    final remaining = timeRemaining;
    return remaining != null && remaining <= 0;
  }

  PKBattleInfo copyWith({
    String? pkId,
    String? hostAId,
    String? hostAName,
    String? hostBId,
    String? hostBName,
    PKBattleState? state,
    DateTime? startTime,
    int? durationSeconds,
    Map<String, String>? votes,
  }) {
    return PKBattleInfo(
      pkId: pkId ?? this.pkId,
      hostAId: hostAId ?? this.hostAId,
      hostAName: hostAName ?? this.hostAName,
      hostBId: hostBId ?? this.hostBId,
      hostBName: hostBName ?? this.hostBName,
      state: state ?? this.state,
      startTime: startTime ?? this.startTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      votes: votes ?? this.votes,
    );
  }

  // Convert to/from JSON for room attributes
  Map<String, String> toRoomAttributes() {
    return {
      'pk_id': pkId,
      'pk_hostA_id': hostAId,
      'pk_hostA_name': hostAName,
      'pk_hostB_id': hostBId,
      'pk_hostB_name': hostBName,
      'pk_state': state.name,
      'pk_start_time': startTime?.toIso8601String() ?? '',
      'pk_duration': durationSeconds.toString(),
      'pk_votes_A': hostAVotes.toString(),
      'pk_votes_B': hostBVotes.toString(),
    };
  }

  static PKBattleInfo? fromRoomAttributes(Map<String, String> attrs) {
    try {
      final pkId = attrs['pk_id'];
      final hostAId = attrs['pk_hostA_id'];
      final hostBId = attrs['pk_hostB_id'];

      if (pkId == null || hostAId == null || hostBId == null) {
        return null;
      }

      return PKBattleInfo(
        pkId: pkId,
        hostAId: hostAId,
        hostAName: attrs['pk_hostA_name'] ?? '',
        hostBId: hostBId,
        hostBName: attrs['pk_hostB_name'] ?? '',
        state: PKBattleState.values.firstWhere(
          (e) => e.name == attrs['pk_state'],
          orElse: () => PKBattleState.idle,
        ),
        startTime: attrs['pk_start_time']?.isNotEmpty == true
            ? DateTime.tryParse(attrs['pk_start_time']!)
            : null,
        durationSeconds: int.tryParse(attrs['pk_duration'] ?? '300') ?? 300,
      );
    } catch (e) {
      debugPrint('Error parsing PK battle from room attributes: $e');
      return null;
    }
  }

  @override
  String toString() {
    return 'PKBattleInfo(id: $pkId, hostA: $hostAName, hostB: $hostBName, '
        'state: ${state.name}, votes: $hostAVotes vs $hostBVotes)';
  }
}
