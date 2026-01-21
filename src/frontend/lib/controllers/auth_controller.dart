import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../app/app.dart';
import '../app/theme.dart';
import '../models/app_user.dart';
import '../models/user_location.dart';
import '../services/auth_service.dart';
import '../services/graphql_client.dart';
import 'location_controller.dart';

/// AuthController handles authentication using OAuth token exchange pattern:
/// 1. Flutter handles Google Sign-In natively
/// 2. Flutter receives Google ID Token
/// 3. Flutter sends ID Token → Django backend
/// 4. Django verifies token with Google & issues JWT
/// 5. Flutter stores JWT for future API calls
class AuthController extends GetxController {
  // Google Sign-In instance
  final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: dotenv.env['GOOGLE_CLIENT_ID'],
  );

  // Storage & Services
  final _storage = GetStorage();
  final _authService = AuthService();

  // Reactive state
  final user = Rxn<AppUser>();
  final isAuthenticated = false.obs;
  final accessToken = RxnString();
  final refreshToken = RxnString();
  final isLoading = false.obs;
  final errorMessage = RxnString();

  /// 👇 NEW: active role (frontend concern)
  final activeRole = 'BUYER'.obs;
  // Global reactive boolean tracking whether the active role is RUNNER
  final RxBool _isRunnerActive = false.obs;

  // Convenience getters
  String get userName => user.value?.name ?? '';
  String get userEmail => user.value?.email ?? '';
  String get avatarUrl => user.value?.avatar ?? '';
  int get trustScore => user.value?.trustScore ?? 0;
  List<String> get userRoles => user.value?.roles ?? [];
  List<UserLocation> get userLocations => user.value?.locations ?? [];

  bool get isRunner => userRoles.contains('RUNNER');
  /// Public getter for the reactive runner-active flag
  bool get isRunnerActive => _isRunnerActive.value;
  // Expose the Rx if other code needs to watch it directly
  RxBool get isRunnerActiveRx => _isRunnerActive;
  bool get isBuyerActive => activeRole.value == 'BUYER';

  @override
  void onInit() {
    super.onInit();
    // Keep _isRunnerActive synchronized with activeRole globally
    ever<String>(activeRole, (val) {
      _isRunnerActive.value = (val == 'RUNNER');
    });

    _restoreSession();
  }

  /// Restores user session from local storage on app start
  void _restoreSession() {
    print('🔄 [Auth] Restoring session from local storage...');
    final storedToken = _storage.read<String>('accessToken');
    final storedRefreshToken = _storage.read<String>('refreshToken');
    final storedUserJson = _storage.read<String>('user');
    final storedRole = _storage.read<String>('activeRole');

    if (storedToken == null || storedToken.isEmpty) {
      print('📭 [Auth] No stored token found');
      return;
    }

    accessToken.value = storedToken;
    refreshToken.value = storedRefreshToken;

    if (storedUserJson != null && storedUserJson.isNotEmpty) {
      try {
        final userMap = jsonDecode(storedUserJson) as Map<String, dynamic>;
        user.value = AppUser.fromJson(userMap);
        isAuthenticated.value = true;

        if (storedRole != null && userRoles.contains(storedRole)) {
          activeRole.value = storedRole;
        } else {
          activeRole.value = 'BUYER';
        }

        GraphQLClientInstance.setToken(storedToken);
        print('✅ [Auth] Session restored for: ${user.value?.email}');
      } catch (e) {
        print('❌ [Auth] Failed to restore session: $e');
        _clearSession();
      }
    }
  }

  /// Login flow (UNCHANGED)
  Future<void> login() async {
    if (isLoading.value) return;

    try {
      isLoading.value = true;
      errorMessage.value = null;

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) throw AuthException('Missing Google ID token');

      final authResponse = await _authService.verifyGoogleToken(idToken);

      _setSession(
        token: authResponse.accessToken,
        refreshToken: authResponse.refreshToken,
        userData: authResponse.user,
      );

      _showSnackBar(
        message: 'Welcome, ${authResponse.user.name}!',
        isError: false,
      );
    } catch (e) {
      debugPrint("❌ [Auth] Login error: $e");
      errorMessage.value = e.toString();
      _showSnackBar(message: 'Login failed', isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  /// Sets the session state and persists to storage
  void _setSession({
    required String token,
    required String refreshToken,
    required AppUser userData,
  }) {
    user.value = userData;
    accessToken.value = token;
    this.refreshToken.value = refreshToken;
    isAuthenticated.value = true;

    // default active role when setting a new session
    activeRole.value = 'BUYER';
    _isRunnerActive.value = false;

    _storage.write('accessToken', token);
    _storage.write('refreshToken', refreshToken);
    _storage.write('user', jsonEncode(userData.toJson()));
    _storage.write('activeRole', 'BUYER');

    GraphQLClientInstance.setToken(token);
  }

  /// 👇 NEW: Become runner (backend mutation)
  Future<void> becomeRunner(GraphQLClient client) async {
    print('🏃 [Auth] Becoming runner...');

    final result = await client.mutate(
      MutationOptions(
        document: gql(r'''
          mutation BecomeRunner {
            becomeRunner {
              ok
            }
          }
        '''),
        fetchPolicy: FetchPolicy.noCache,
      ),
    );

    if (result.hasException) {
      throw AuthException('Failed to become runner');
    }

    if (!userRoles.contains('RUNNER')) {
      final old = user.value!;
      user.value = AppUser(
        id: old.id,
        name: old.name,
        email: old.email,
        avatar: old.avatar,
        trustScore: old.trustScore,
        roles: [...userRoles, 'RUNNER'],
        locations: old.locations,
      );
      _storage.write('user', jsonEncode(user.value!.toJson()));
    }

    switchRole('RUNNER');
  }

  /// 👇 NEW: Switch active role (frontend only)
  void switchRole(String role) {
    if (!userRoles.contains(role)) return;
    activeRole.value = role;
    _isRunnerActive.value = (role == 'RUNNER');
    _storage.write('activeRole', role);

    print('🔄 [Auth] Switched role to $role');
    print('🔄 UserRoles: $userRoles');
  }

  /// Syncs user location with backend (UNCHANGED)
  Future<void> syncLocation() async {
    if (!isAuthenticated.value) return;

    final locationPayload = Get.find<LocationController>().toPayload();
    if (locationPayload.isEmpty) return;

    await _authService.updateLocation(
      mode: locationPayload['mode'],
      latitude: (locationPayload['latitude'] as num).toDouble(),
      longitude: (locationPayload['longitude'] as num).toDouble(),
      address: locationPayload['address'],
    );
  }

  /// Logout
  Future<void> logout() async {
    await _googleSignIn.signOut();
    _clearSession();

    _showSnackBar(
      message: 'Logged out successfully',
      isError: false,
    );
  }

  /// Clears session
  void _clearSession() {
    user.value = null;
    accessToken.value = null;
    refreshToken.value = null;
    isAuthenticated.value = false;
    activeRole.value = 'BUYER';
    _isRunnerActive.value = false;

    _storage.erase();
    GraphQLClientInstance.init();
  }

  void _showSnackBar({required String message, required bool isError}) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
      ),
    );
  }
}

/// Custom exception
class AuthException implements Exception {
  final String message;
  AuthException(this.message);
}
