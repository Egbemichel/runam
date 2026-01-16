import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
  // Google Sign-In instance - handles native Google authentication
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

  // Convenience getters
  String get userName => user.value?.name ?? '';
  String get userEmail => user.value?.email ?? '';
  String get avatarUrl => user.value?.avatar ?? '';
  int get trustScore => user.value?.trustScore ?? 0;
  List<String> get userRoles => user.value?.roles ?? [];
  List<UserLocation> get userLocations => user.value?.locations ?? [];

  @override
  void onInit() {
    super.onInit();
    _restoreSession();
  }

  /// Restores user session from local storage on app start
  void _restoreSession() {
    print('🔄 [Auth] Restoring session from local storage...');
    final storedToken = _storage.read<String>('accessToken');
    final storedRefreshToken = _storage.read<String>('refreshToken');
    final storedUserJson = _storage.read<String>('user');

    if (storedToken == null || storedToken.isEmpty) {
      print('📭 [Auth] No stored token found');
      return;
    }

    accessToken.value = storedToken;
    refreshToken.value = storedRefreshToken;
    print('🔑 [Auth] Token restored');

    if (storedUserJson != null && storedUserJson.isNotEmpty) {
      try {
        final userMap = jsonDecode(storedUserJson) as Map<String, dynamic>;
        user.value = AppUser.fromJson(userMap);
        isAuthenticated.value = true;
        GraphQLClientInstance.setToken(storedToken);
        print('✅ [Auth] Session restored for: ${user.value?.email}');
      } catch (e) {
        print('❌ [Auth] Failed to restore session: $e');
        _clearSession();
      }
    }
  }

  /// Main login flow using OAuth token exchange pattern
  /// 1. Google Sign-In on Flutter (native)
  /// 2. Get Google ID Token
  /// 3. Send to Django backend for verification
  /// 4. Receive Django JWT + user data
  Future<void> login() async {
    if (isLoading.value) {
      print('🔒 [Auth] Login already in progress, skipping...');
      return;
    }

    try {
      isLoading.value = true;
      errorMessage.value = null;
      print('🚀 [Auth] Starting login flow...');
      print('🔧 [Auth] Google Client ID: ${dotenv.env['GOOGLE_CLIENT_ID']}');

      // Step 1: Initiate Google Sign-In on Flutter
      print('📱 [Auth] Step 1: Initiating Google Sign-In...');

      GoogleSignInAccount? googleUser;
      try {
        googleUser = await _googleSignIn.signIn().timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            print('⏰ [Auth] Google Sign-In timed out after 60 seconds');
            return null;
          },
        );
      } catch (e) {
        print('❌ [Auth] Google Sign-In error: $e');
        throw AuthException('Google Sign-In failed: $e');
      }

      if (googleUser == null) {
        print('❌ [Auth] User cancelled Google Sign-In or timeout');
        isLoading.value = false;
        return;
      }
      print('✅ [Auth] Google Sign-In successful: ${googleUser.email}');

      // Step 2: Get Google ID Token
      print('🔑 [Auth] Step 2: Getting Google authentication tokens...');

      GoogleSignInAuthentication? googleAuth;
      try {
        googleAuth = await googleUser.authentication.timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            print('⏰ [Auth] Getting auth tokens timed out after 30 seconds');
            throw AuthException('Timeout getting Google tokens');
          },
        );
      } catch (e) {
        print('❌ [Auth] Failed to get Google auth tokens: $e');
        throw AuthException('Failed to get Google authentication: $e');
      }

      final idToken = googleAuth.idToken;
      print('🔑 [Auth] Access Token: ${googleAuth.accessToken != null ? "Present" : "Missing"}');
      print('🔑 [Auth] ID Token: ${idToken != null ? "Present (${idToken.length} chars)" : "Missing"}');

      if (idToken == null) {
        print('❌ [Auth] Failed to obtain Google ID token');
        throw AuthException('Failed to obtain Google ID token');
      }

      // Step 3: Send ID Token to Django backend for verification
      print('🌐 [Auth] Step 3: Sending ID token to backend for verification...');
      print('🌐 [Auth] Backend URL: ${GraphQLClientInstance.currentUrl}');

      // First, test if we can reach the backend
      try {
        final testUrl = Uri.parse(GraphQLClientInstance.currentUrl ?? '');
        print('🔍 [Auth] Testing connectivity to ${testUrl.host}:${testUrl.port}...');
      } catch (e) {
        print('⚠️ [Auth] Could not parse backend URL: $e');
      }

      final authResponse = await _authService.verifyGoogleToken(idToken).timeout(
        const Duration(seconds: 60), // Increased timeout
        onTimeout: () {
          print('⏰ [Auth] Backend verification timed out after 60 seconds');
          print('💡 [Auth] Hint: Check if backend is running and accessible at ${GraphQLClientInstance.currentUrl}');
          throw AuthException('Backend not responding. Please check your connection and ensure the server is running.');
        },
      );
      print('✅ [Auth] Backend verification successful!');
      print('👤 [Auth] User: ${authResponse.user.name} (${authResponse.user.email})');
      print('🔁 Refresh token length: ${authResponse.refreshToken.length}');

      // Step 4: Store Django-issued JWT and user data
      print('💾 [Auth] Step 4: Storing session...');
      _setSession(
        token: authResponse.accessToken,
        refreshToken: authResponse.refreshToken ?? '',
        userData: authResponse.user,
      );
      print('✅ [Auth] Session stored successfully!');

      // Show success message
      _showSnackBar(
        message: 'Welcome, ${authResponse.user.name}!',
        isError: false,
      );
      print('🎉 [Auth] Login complete!');
    } on AuthException catch (e) {
      errorMessage.value = e.message;
      print('❌ [Auth] AuthException: ${e.message}');
      _showSnackBar(message: e.message, isError: true);
    } catch (e, stackTrace) {
      errorMessage.value = 'An unexpected error occurred';
      print('❌ [Auth] Unexpected error: $e');
      print('📚 [Auth] Stack trace: $stackTrace');
      _showSnackBar(message: 'Login failed. Please try again.', isError: true);
    } finally {
      isLoading.value = false;
      print('🏁 [Auth] Login flow ended, isLoading = false');
    }
  }

  /// Sets the session state and persists to storage
  void _setSession({required String token, required String refreshToken, required AppUser userData}) {
    user.value = userData;
    accessToken.value = token;
    this.refreshToken.value = refreshToken;
    isAuthenticated.value = true;

    // Persist to local storage
    _storage.write('accessToken', token);
    _storage.write('refreshToken', refreshToken);
    _storage.write('user', jsonEncode(userData.toJson()));

    // Update GraphQL client with Django JWT for future API calls
    GraphQLClientInstance.setToken(token);
  }

  /// Clears the session state and storage
  void _clearSession() {
    user.value = null;
    accessToken.value = null;
    isAuthenticated.value = false;
    errorMessage.value = null;

    _storage.remove('accessToken');
    _storage.remove('refreshToken');
    _storage.remove('user');

    GraphQLClientInstance.init();
  }

  /// Syncs user location with the backend
  Future<void> syncLocation() async {
    print('📍 [Auth] === SYNC LOCATION TO BACKEND ===');

    if (!isAuthenticated.value) {
      print('📍 [Auth] User not authenticated, skipping location sync');
      return;
    }

    try {
      final locationPayload = Get.find<LocationController>().toPayload();
      print('📍 [Auth] Location payload: $locationPayload');

      if (locationPayload.isEmpty) {
        print('📍 [Auth] Location payload is empty, skipping sync');
        return;
      }

      print('📍 [Auth] Sending location to backend...');
      print('📍 [Auth] Mode: ${locationPayload['mode']}');
      print('📍 [Auth] Latitude: ${locationPayload['latitude']}');
      print('📍 [Auth] Longitude: ${locationPayload['longitude']}');
      print('📍 [Auth] Address: ${locationPayload['address']}');

      final success = await _authService.updateLocation(
        mode: locationPayload['mode'],
        latitude: (locationPayload['latitude'] as num).toDouble(),
        longitude: (locationPayload['longitude'] as num).toDouble(),
        address: locationPayload['address'],
      );

      if (success) {
        print('✅ [Auth] Location synced successfully to backend!');
      } else {
        print('❌ [Auth] Location sync failed.');
      }
    } catch (e) {
      print('❌ [Auth] Failed to sync location: $e');
    }
  }


  /// Logs out the user
  Future<void> logout() async {
    print('👋 [Auth] Logging out...');
    try {
      // Sign out from Google
      await _googleSignIn.signOut();
      // Optionally notify backend
      await _authService.logout();
    } catch (_) {
      // Continue with local logout even if remote fails
    }

    _clearSession();
    print('✅ [Auth] Logged out successfully');

    _showSnackBar(
      message: 'You have been logged out successfully',
      isError: false,
    );
  }

  /// Shows a snackbar using Flutter's ScaffoldMessenger
  void _showSnackBar({required String message, required bool isError}) {
    try {
      // Use the global scaffoldMessengerKey directly
      final messenger = scaffoldMessengerKey.currentState;
      if (messenger == null) {
        print('⚠️ [Auth] Cannot show snackbar - scaffoldMessengerKey.currentState is null');
        return;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: isError ? AppTheme.error : AppTheme.success,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: Duration(seconds: isError ? 4 : 2),
        ),
      );
    } catch (e) {
      print('⚠️ [Auth] Failed to show snackbar: $e');
    }
  }
}

/// Custom exception for authentication errors
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

