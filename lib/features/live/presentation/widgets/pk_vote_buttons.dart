import 'package:flutter/material.dart';
import 'package:test_flutter/core/theme/app_theme.dart';
import 'package:test_flutter/features/live/domain/models/pk_battle_models.dart';
import 'package:test_flutter/features/live/presentation/managers/pk_battle_manager.dart';

/// Vote buttons for audience during PK battles
class PKVoteButtons extends StatefulWidget {
  final String myUserId;
  final PKBattleInfo pkInfo;

  const PKVoteButtons({
    super.key,
    required this.myUserId,
    required this.pkInfo,
  });

  @override
  State<PKVoteButtons> createState() => _PKVoteButtonsState();
}

class _PKVoteButtonsState extends State<PKVoteButtons>
    with SingleTickerProviderStateMixin {
  final PKBattleManager _pkManager = PKBattleManager();
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  String? _votedFor;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 150,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildVoteButton(
              widget.pkInfo.hostAId,
              widget.pkInfo.hostAName,
              isLeft: true,
            ),
            _buildVoteButton(
              widget.pkInfo.hostBId,
              widget.pkInfo.hostBName,
              isLeft: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoteButton(
    String hostId,
    String hostName, {
    required bool isLeft,
  }) {
    final isVoted = _votedFor == hostId;
    final color = isLeft ? AppColors.neonCyan : AppColors.neonPurple;

    return GestureDetector(
      onTap: () => _vote(hostId),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          final scale = isVoted ? _scaleAnimation.value : 1.0;
          return Transform.scale(
            scale: scale,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isVoted
                      ? [color, color.withValues(alpha: 0.6)]
                      : [
                          color.withValues(alpha: 0.3),
                          color.withValues(alpha: 0.1),
                        ],
                ),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: color, width: isVoted ? 3 : 2),
                boxShadow: isVoted
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.6),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isVoted ? Icons.favorite : Icons.favorite_border,
                    color: color,
                    size: 32,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Vote',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'Orbitron',
                      fontWeight: isVoted ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _vote(String hostId) {
    if (_votedFor == hostId) return; // Already voted for this host

    setState(() {
      _votedFor = hostId;
    });

    _pkManager.recordVote(widget.myUserId, hostId);
    _animController.forward().then((_) => _animController.reverse());

    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Voted for ${hostId == widget.pkInfo.hostAId ? widget.pkInfo.hostAName : widget.pkInfo.hostBName}!',
        ),
        backgroundColor: hostId == widget.pkInfo.hostAId
            ? AppColors.neonCyan
            : AppColors.neonPurple,
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
