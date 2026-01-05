import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:test_flutter/features/live/domain/models/gift_item.dart';

class GiftManager {
  static final GiftManager _instance = GiftManager._internal();
  factory GiftManager() => _instance;
  GiftManager._internal();

  // Available gifts catalog
  static final List<GiftItem> availableGifts = [
    const GiftItem(id: '1', name: 'Coffee', emoji: '☕', price: 10),
    const GiftItem(id: '2', name: 'Heart', emoji: '❤️', price: 50),
    const GiftItem(id: '3', name: 'Diamond', emoji: '💎', price: 100),
    const GiftItem(id: '4', name: 'Rocket', emoji: '🚀', price: 200),
    const GiftItem(id: '5', name: 'Crown', emoji: '👑', price: 500),
    const GiftItem(id: '6', name: 'Trophy', emoji: '🏆', price: 1000),
  ];

  // Animation queue
  final StreamController<GiftMessage> _animationController =
      StreamController<GiftMessage>.broadcast();
  Stream<GiftMessage> get animationStream => _animationController.stream;

  // Send gift via ZegoUIKit
  Future<bool> sendGift({
    required String senderUserId,
    required String senderUserName,
    required GiftItem gift,
    required int count,
  }) async {
    try {
      final message = GiftMessage(
        senderUserId: senderUserId,
        senderUserName: senderUserName,
        gift: gift,
        count: count,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      // Send as in-room command message
      final messageJson = jsonEncode(message.toJson());
      await ZegoUIKit().sendInRoomCommand(
        messageJson,
        [], // Empty list means broadcast to all users
      );

      debugPrint('Gift sent: ${gift.name} x$count');
      return true;
    } catch (e) {
      debugPrint('Failed to send gift: $e');
      return false;
    }
  }

  // Add gift to animation queue (for local playback)
  void playGiftAnimation(GiftMessage message) {
    _animationController.add(message);
  }

  void dispose() {
    _animationController.close();
  }
}
