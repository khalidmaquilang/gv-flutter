import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/profile/data/services/profile_service.dart';

final profileServiceProvider = Provider((ref) => ProfileService());
