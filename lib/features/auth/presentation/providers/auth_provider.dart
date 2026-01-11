import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/models/user_model.dart';
import '../../data/services/auth_service.dart';
import '../../../../core/providers/api_provider.dart';
import '../../../../core/services/broadcasting_service.dart';

final authServiceProvider = Provider((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthService(apiClient: apiClient);
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<User?>>((ref) {
      return AuthController(ref.read(authServiceProvider));
    });

class AuthController extends StateNotifier<AsyncValue<User?>> {
  final AuthService _authService;

  AuthController(this._authService) : super(const AsyncValue.data(null));

  Future<void> login(String email, String password) async {
    try {
      final user = await _authService.login(email, password);
      state = AsyncValue.data(user);

      // Initialize broadcasting for real-time chat
      try {
        final broadcastingService = BroadcastingService();
        final token = await const FlutterSecureStorage().read(
          key: 'auth_token',
        );
        if (token != null) {
          await broadcastingService.initialize(user.id, token);
        }
      } catch (e) {
        print('Broadcasting initialization error: $e');
        // Don't fail login if broadcasting fails
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<String?> register(
    String name,
    String email,
    String password,
    String passwordConfirmation,
  ) async {
    try {
      final message = await _authService.register(
        name,
        email,
        password,
        passwordConfirmation,
      );
      // We do NOT update global state here because the user is not logged in yet.
      // They need to verify their email first.
      return message;
    } catch (e) {
      // On failure, rethrow to handle locally in RegisterScreen
      rethrow;
    }
  }

  Future<String?> forgotPassword(String email) async {
    try {
      final message = await _authService.forgotPassword(email);
      return message;
    } catch (e) {
      // Don't update global state for forgot password errors to avoid
      // polluting LoginScreen or other listeners.
      rethrow;
    }
  }

  void updateUser(User user) {
    state = AsyncValue.data(user);
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const AsyncValue.data(null);
  }

  Future<void> checkAuthStatus() async {
    // Delay to ensure we are not in the middle of a build or init frame
    await Future.delayed(Duration.zero);

    state = const AsyncValue.loading();
    try {
      final user = await _authService.restoreSession();
      state = AsyncValue.data(user);

      // Initialize broadcasting if user session restored
      if (user != null) {
        try {
          final broadcastingService = BroadcastingService();
          final token = await const FlutterSecureStorage().read(
            key: 'auth_token',
          );
          if (token != null) {
            await broadcastingService.initialize(user.id, token);
          }
        } catch (e) {
          print('Broadcasting initialization error on restore: $e');
          // Don't fail session restore if broadcasting fails
        }
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
