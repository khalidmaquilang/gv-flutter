import 'package:flutter/material.dart';
import 'package:test_flutter/core/theme/app_theme.dart';
import 'package:test_flutter/features/live/domain/models/gift_item.dart';
import 'package:test_flutter/features/live/presentation/managers/gift_manager.dart';

class GiftBottomSheet extends StatefulWidget {
  final String senderUserId;
  final String senderUserName;
  final int currentCoinBalance;

  const GiftBottomSheet({
    super.key,
    required this.senderUserId,
    required this.senderUserName,
    required this.currentCoinBalance,
  });

  @override
  State<GiftBottomSheet> createState() => _GiftBottomSheetState();
}

class _GiftBottomSheetState extends State<GiftBottomSheet> {
  GiftItem? _selectedGift;
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.deepVoid,
            AppColors.deepVoid.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.neonCyan, width: 2)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Send Gift',
                    style: TextStyle(
                      color: AppColors.neonCyan,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.monetization_on,
                        color: Colors.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.currentCoinBalance}',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Gift Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.9,
                ),
                itemCount: GiftManager.availableGifts.length,
                itemBuilder: (context, index) {
                  final gift = GiftManager.availableGifts[index];
                  final isSelected = _selectedGift?.id == gift.id;
                  final canAfford =
                      widget.currentCoinBalance >= gift.price * _quantity;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedGift = gift;
                        _quantity = 1;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.neonPink.withValues(alpha: 0.2)
                            : Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.neonPink
                              : Colors.grey[800]!,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            gift.emoji,
                            style: const TextStyle(fontSize: 40),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            gift.name,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          Text(
                            '${gift.price} 🪙',
                            style: TextStyle(
                              color: canAfford ? Colors.amber : Colors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Quantity Selector
              if (_selectedGift != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _quantity > 1
                          ? () => setState(() => _quantity--)
                          : null,
                      icon: Icon(
                        Icons.remove_circle,
                        color: _quantity > 1
                            ? AppColors.neonCyan
                            : Colors.grey[700],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.neonCyan),
                      ),
                      child: Text(
                        '$_quantity',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed:
                          (_selectedGift!.price * (_quantity + 1) <=
                              widget.currentCoinBalance)
                          ? () => setState(() => _quantity++)
                          : null,
                      icon: Icon(
                        Icons.add_circle,
                        color:
                            (_selectedGift!.price * (_quantity + 1) <=
                                widget.currentCoinBalance)
                            ? AppColors.neonCyan
                            : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Send Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        (_selectedGift!.price * _quantity <=
                            widget.currentCoinBalance)
                        ? () => _sendGift()
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.neonPink,
                      disabledBackgroundColor: Colors.grey[800],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'SEND ${_selectedGift!.price * _quantity} 🪙',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendGift() async {
    if (_selectedGift == null) return;

    // Play animation locally
    final message = GiftMessage(
      senderUserId: widget.senderUserId,
      senderUserName: widget.senderUserName,
      gift: _selectedGift!,
      count: _quantity,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    GiftManager().playGiftAnimation(message);

    // Send to remote users
    try {
      await GiftManager().sendGift(
        senderUserId: widget.senderUserId,
        senderUserName: widget.senderUserName,
        gift: _selectedGift!,
        count: _quantity,
      );

      // Close bottom sheet without success snackbar
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      // Only show snackbar on error
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send gift'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
