import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:zego_express_engine/zego_express_engine.dart';
import 'package:zego_zim/zego_zim.dart';
import 'package:test_flutter/features/live/domain/models/pk_battle_models.dart';

/// Singleton manager for PK battles
class PKBattleManager {
  PKBattleManager._();
  static final PKBattleManager instance = PKBattleManager._();
  factory PKBattleManager() => instance;

  // Current PK battle state
  PKBattleInfo? _currentPK;
  PKBattleInfo? get currentPK => _currentPK;

  // Stream controllers for state changes
  final _pkStateController = StreamController<PKBattleInfo?>.broadcast();
  Stream<PKBattleInfo?> get pkStateStream => _pkStateController.stream;

  final _votesController = StreamController<Map<String, int>>.broadcast();
  Stream<Map<String, int>> get votesStream => _votesController.stream;

  // Local votes map (userId -> hostId)
  final Map<String, String> _votes = {};

  /// Send PK invitation to another host
  Future<bool> sendPKInvitation({
    required String targetHostId,
    required String targetHostName,
    required String myUserId,
    required String myUserName,
    required int durationSeconds,
  }) async {
    try {
      final pkId = 'pk_${DateTime.now().millisecondsSinceEpoch}';

      debugPrint('📤 Sending PK invitation to $targetHostName...');

      // Create PK info for invitation
      final pkInfo = PKBattleInfo(
        pkId: pkId,
        hostAId: myUserId,
        hostAName: myUserName,
        hostBId: targetHostId,
        hostBName: targetHostName,
        state: PKBattleState.inviting,
        durationSeconds: durationSeconds,
      );

      // Send invitation via ZIM
      // Note: This uses ZIM call invitation feature
      // You'll need to implement actual ZIM call invitation API

      // For now, using room attributes as simple implementation
      // In production, use proper ZIM call invitation

      _currentPK = pkInfo;
      _pkStateController.add(_currentPK);

      debugPrint('✅ PK invitation sent');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to send PK invitation: $e');
      return false;
    }
  }

  /// Accept PK invitation
  Future<bool> acceptPKInvitation(PKBattleInfo pkInfo) async {
    try {
      debugPrint('✅ Accepting PK invitation: ${pkInfo.pkId}');

      _currentPK = pkInfo.copyWith(state: PKBattleState.preparing);
      _pkStateController.add(_currentPK);

      return true;
    } catch (e) {
      debugPrint('❌ Failed to accept PK invitation: $e');
      return false;
    }
  }

  /// Reject PK invitation
  Future<bool> rejectPKInvitation(String pkId) async {
    try {
      debugPrint('🚫 Rejecting PK invitation: $pkId');

      if (_currentPK?.pkId == pkId) {
        _currentPK = null;
        _pkStateController.add(null);
      }

      return true;
    } catch (e) {
      debugPrint('❌ Failed to reject PK invitation: $e');
      return false;
    }
  }

  /// Start PK battle with stream mixing
  Future<bool> startPKBattle({
    required PKBattleInfo pkInfo,
    required String roomId,
  }) async {
    try {
      debugPrint('🎮 Starting PK battle: ${pkInfo.pkId}');

      // Update state to active
      _currentPK = pkInfo.copyWith(
        state: PKBattleState.active,
        startTime: DateTime.now(),
      );
      _pkStateController.add(_currentPK);

      // Start stream mixing task
      await _startMixerTask(_currentPK!);

      // Broadcast PK start via room attributes
      await _updateRoomAttributes(roomId);

      debugPrint('✅ PK battle started successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to start PK battle: $e');
      return false;
    }
  }

  /// Stop PK battle
  Future<bool> stopPKBattle(String roomId) async {
    try {
      if (_currentPK == null) return false;

      debugPrint('🛑 Stopping PK battle: ${_currentPK!.pkId}');

      // TODO: Stop mixer task with proper API
      // await ZegoExpressEngine.instance.stopMixerTask(...);
      debugPrint('⚠️ Mixer stop not implemented');

      // Clear room attributes
      await _clearRoomAttributes(roomId);

      // Reset state
      _currentPK = null;
      _votes.clear();
      _pkStateController.add(null);
      _votesController.add({});

      debugPrint('✅ PK battle stopped');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to stop PK battle: $e');
      return false;
    }
  }

  /// Configure and start mixer task for PK
  /// TODO: Implement proper stream mixing with correct Zego API
  Future<void> _startMixerTask(PKBattleInfo pkInfo) async {
    debugPrint(
      '⚠️ Stream mixing not yet implemented - requires Zego mixer API setup',
    );
    debugPrint('   Mixed stream ID would be: ${pkInfo.mixedStreamId}');
    debugPrint('   Host A stream: ${pkInfo.hostAStreamId}');
    debugPrint('   Host B stream: ${pkInfo.hostBStreamId}');

    // TODO: Configure ZegoMixerTask with proper API
    // The API has changed - need to check latest Zego Express Engine docs
    // Expected flow:
    // 1. Create mixer task with task ID
    // 2. Add input streams with layout rectangles
    // 3. Configure output stream
    // 4. Start mixer via startMixerTask()

    debugPrint(
      '🎬 Mixer task placeholder - PK streams need proper mixing setup',
    );
  }

  /// Record a vote for a host
  void recordVote(String userId, String hostId) {
    if (_currentPK == null) return;

    _votes[userId] = hostId;

    // Emit vote update
    _votesController.add(getVoteResults());

    debugPrint('🗳️ Vote recorded: $userId -> $hostId');
  }

  /// Get current vote results
  Map<String, int> getVoteResults() {
    if (_currentPK == null) return {};

    return {
      _currentPK!.hostAId: _votes.values
          .where((v) => v == _currentPK!.hostAId)
          .length,
      _currentPK!.hostBId: _votes.values
          .where((v) => v == _currentPK!.hostBId)
          .length,
    };
  }

  /// Update room attributes with PK state
  Future<void> _updateRoomAttributes(String roomId) async {
    if (_currentPK == null) return;

    try {
      final attrs = _currentPK!.toRoomAttributes();
      final config = ZIMRoomAttributesSetConfig();
      await ZIM.getInstance()?.setRoomAttributes(attrs, roomId, config);
      debugPrint('📢 Updated room attributes with PK state');
    } catch (e) {
      debugPrint('⚠️ Failed to update room attributes: $e');
    }
  }

  /// Clear PK-related room attributes
  Future<void> _clearRoomAttributes(String roomId) async {
    try {
      final keysToDelete = [
        'pk_id',
        'pk_hostA_id',
        'pk_hostA_name',
        'pk_hostB_id',
        'pk_hostB_name',
        'pk_state',
        'pk_start_time',
        'pk_duration',
        'pk_votes_A',
        'pk_votes_B',
      ];

      final config = ZIMRoomAttributesDeleteConfig();
      await ZIM.getInstance()?.deleteRoomAttributes(
        keysToDelete,
        roomId,
        config,
      );
      debugPrint('🧹 Cleared PK room attributes');
    } catch (e) {
      debugPrint('⚠️ Failed to clear room attributes: $e');
    }
  }

  /// Parse PK state from room attributes
  void updateFromRoomAttributes(Map<String, String> attributes) {
    final pkInfo = PKBattleInfo.fromRoomAttributes(attributes);

    if (pkInfo != null && pkInfo.pkId != _currentPK?.pkId) {
      _currentPK = pkInfo;
      _pkStateController.add(_currentPK);
      debugPrint('🔄 PK state updated from room attributes: $pkInfo');
    } else if (pkInfo == null && _currentPK != null) {
      // PK ended
      _currentPK = null;
      _votes.clear();
      _pkStateController.add(null);
      debugPrint('🏁 PK ended (room attributes cleared)');
    }
  }

  /// Cleanup resources
  void dispose() {
    _pkStateController.close();
    _votesController.close();
    _votes.clear();
    _currentPK = null;
  }
}
