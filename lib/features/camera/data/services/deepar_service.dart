import 'package:deepar_flutter_plus/deepar_flutter_plus.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/api_constants.dart';

class DeepArService {
  static Future<DeepArControllerPlus> initialize() async {
    final DeepArControllerPlus controller = DeepArControllerPlus();
    try {
      final result = await controller.initialize(
        androidLicenseKey: ApiConstants.deepArAndroidLicenseKey,
        iosLicenseKey: ApiConstants.deepArIosLicenseKey,
        resolution: Resolution.medium,
      );
      if (result.success ?? false) {
        // Handle potential null success
        debugPrint("DeepAR initialized successfully: ${result.message}");
      } else {
        debugPrint("DeepAR initialization failed: ${result.message}");
      }
    } catch (e) {
      debugPrint("DeepAR initialization threw exception: $e");
    }
    return controller;
  }
}
