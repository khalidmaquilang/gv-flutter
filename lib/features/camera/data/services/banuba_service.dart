import 'package:banuba_sdk/banuba_sdk.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/api_constants.dart';

class BanubaService {
  static Future<BanubaSdkManager?> initialize() async {
    final BanubaSdkManager manager = BanubaSdkManager();
    try {
      await manager.initialize(
        [],
        ApiConstants.banubaToken,
        SeverityLevel.info,
      );
      debugPrint("Banuba SDK initialized successfully");
      return manager;
    } catch (e) {
      debugPrint("Banuba SDK initialization failed: $e");
      return null;
    }
  }
}
