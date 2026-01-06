import 'package:flutter/material.dart';
import 'package:test_flutter/core/theme/app_theme.dart';
import 'package:test_flutter/features/live/domain/models/pk_battle_models.dart';
import 'package:test_flutter/features/live/presentation/managers/pk_battle_manager.dart';

/// PK Battle controls for hosts
class PKBattleControls extends StatefulWidget {
  final String myUserId;
  final String myUserName;
  final String channelId;
  final bool isHost;

  const PKBattleControls({
    super.key,
    required this.myUserId,
    required this.myUserName,
    required this.channelId,
    required this.isHost,
  });

  @override
  State<PKBattleControls> createState() => _PKBattleControlsState();
}

class _PKBattleControlsState extends State<PKBattleControls> {
  final PKBattleManager _pkManager = PKBattleManager();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PKBattleInfo?>(
      stream: _pkManager.pkStateStream,
      builder: (context, snapshot) {
        final pkInfo = snapshot.data;

        // Not in PK - show invite button
        if (pkInfo == null && widget.isHost) {
          return _buildInviteButton();
        }

        // In PK - show PK UI
        if (pkInfo != null) {
          return _buildPKActiveUI(pkInfo);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildInviteButton() {
    return Positioned(
      top: 100,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.neonCyan.withValues(alpha: 0.3),
              AppColors.neonPurple.withValues(alpha: 0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.neonCyan, width: 2),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _showInviteDialog,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sports_kabaddi,
                    color: AppColors.neonCyan,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Start PK',
                    style: TextStyle(
                      color: AppColors.neonCyan,
                      fontSize: 14,
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPKActiveUI(PKBattleInfo pkInfo) {
    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.deepVoid.withValues(alpha: 0.9),
              Colors.black.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.neonCyan, width: 2),
        ),
        child: Column(
          children: [
            // PK Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildHostInfo(
                    pkInfo.hostAName,
                    pkInfo.hostAVotes,
                    true,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.neonCyan, AppColors.neonPurple],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'VS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: _buildHostInfo(
                    pkInfo.hostBName,
                    pkInfo.hostBVotes,
                    false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Timer
            if (pkInfo.timeRemaining != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.deepVoid,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.neonCyan, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer, color: AppColors.neonCyan, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(pkInfo.timeRemaining!),
                      style: TextStyle(
                        color: AppColors.neonCyan,
                        fontSize: 14,
                        fontFamily: 'Orbitron',
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // End PK button (host only)
            if (widget.isHost)
              TextButton.icon(
                onPressed: () => _endPK(pkInfo),
                icon: Icon(Icons.stop_circle, color: Colors.red, size: 18),
                label: Text(
                  'End PK',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHostInfo(String name, int votes, bool isLeft) {
    return Column(
      children: [
        Text(
          name,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          textAlign: isLeft ? TextAlign.left : TextAlign.right,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: isLeft
              ? MainAxisAlignment.start
              : MainAxisAlignment.end,
          children: [
            Icon(Icons.favorite, color: Colors.red, size: 16),
            const SizedBox(width: 4),
            Text(
              votes.toString(),
              style: TextStyle(
                color: AppColors.neonCyan,
                fontSize: 16,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _showInviteDialog() {
    final TextEditingController hostIdController = TextEditingController();
    final TextEditingController hostNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.deepVoid,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.neonCyan, width: 2),
        ),
        title: Row(
          children: [
            Icon(Icons.sports_kabaddi, color: AppColors.neonCyan),
            const SizedBox(width: 8),
            Text(
              'Challenge to PK Battle',
              style: TextStyle(
                color: AppColors.neonCyan,
                fontFamily: 'Orbitron',
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Host ID input
            TextField(
              controller: hostIdController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Opponent Host ID',
                labelStyle: TextStyle(color: AppColors.neonCyan),
                hintText: 'Enter host user ID',
                hintStyle: TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.neonCyan),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.neonPurple, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Host Name input
            TextField(
              controller: hostNameController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Opponent Name',
                labelStyle: TextStyle(color: AppColors.neonCyan),
                hintText: 'Enter host name',
                hintStyle: TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.neonCyan),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.neonPurple, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              hostIdController.dispose();
              hostNameController.dispose();
              Navigator.pop(context);
            },
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final hostId = hostIdController.text.trim();
              final hostName = hostNameController.text.trim();

              if (hostId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please enter opponent host ID'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // Send PK invitation
              _pkManager.sendPKInvitation(
                targetHostId: hostId,
                targetHostName: hostName.isEmpty ? hostId : hostName,
                myUserId: widget.myUserId,
                myUserName: widget.myUserName,
                durationSeconds: 300, // 5 minutes
              );

              hostIdController.dispose();
              hostNameController.dispose();
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('PK invitation sent to $hostId'),
                  backgroundColor: AppColors.neonCyan,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonCyan,
              foregroundColor: Colors.black,
            ),
            child: Text('Challenge', style: TextStyle(fontFamily: 'Orbitron')),
          ),
        ],
      ),
    );
  }

  void _endPK(PKBattleInfo pkInfo) async {
    final success = await _pkManager.stopPKBattle(widget.channelId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PK Battle ended'),
          backgroundColor: AppColors.neonCyan,
        ),
      );
    }
  }
}
