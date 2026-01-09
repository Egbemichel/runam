import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';

import '../app/theme.dart';
import '../models/app_user.dart';
import '../models/user_location.dart';
import '../services/auth_service.dart';
import '../services/graphql_client.dart';

class AuthController extends GetxController {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: dotenv.env['GOOGLE_CLIENT_ID'],
  );

  final _storage = GetStorage();
  final _authService = AuthService();

  final user = Rxn<AppUser>();
  final isAuthenticated = false.obs;
  final accessToken = ''.obs;
  final isLoading = false.obs;

  // Convenience getters for common user properties
  String get userName => user.value?.name ?? '';
  String get userEmail => user.value?.email ?? '';
  String get avatarUrl => user.value?.avatar ?? '';
  int get trustScore => user.value?.trustScore ?? 0;
  List<String> get userRoles => user.value?.roles ?? [];
  List<UserLocation> get userLocations => user.value?.locations ?? [];

  @override
  void onInit() {
    super.onInit();
    _loadAuthData();
  }

  void _loadAuthData() {
    final storedToken = _storage.read<String>('accessToken');
    final storedUserJson = _storage.read<String>('user');

    if (storedToken == null || storedToken.isEmpty) return;

    accessToken.value = storedToken;

    if (storedUserJson != null && storedUserJson.isNotEmpty) {
      try {
        final userMap = jsonDecode(storedUserJson) as Map<String, dynamic>;
        user.value = AppUser.fromJson(userMap);
      } catch (e) {
        print('❌ Failed to parse stored user: $e');
      }
    }

    isAuthenticated.value = true;
    GraphQLClientInstance.setToken(storedToken);

    print('✅ Auth restored: ${user.value?.name ?? "Unknown"}');
  }

  Future<void> signInWithGoogle() async {
    try {
      isLoading.value = true;
      print('🔵 Starting Google Sign-In...');

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('⚠️ Google sign-in cancelled by user');
        isLoading.value = false; // Reset loading state
        return;
      }

      print('✅ Google user obtained: ${googleUser.email}');

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Missing Google ID token');
      }

      print('🔵 Sending ID token to backend...');
      final authResponse = await _authService.authenticateWithGoogle(idToken);

      print('✅ Backend response received');
      print('   Access Token: ${authResponse.accessToken.substring(0, 20)}...');
      print('   User Name: ${authResponse.user.name}');
      print('   User Email: ${authResponse.user.email}');
      print('   Trust Score: ${authResponse.user.trustScore}');
      print('   Roles: ${authResponse.user.roles}');
      print('   Locations: ${authResponse.user.locations.length}');

      // Store the complete user object
      user.value = authResponse.user;
      accessToken.value = authResponse.accessToken;
      isAuthenticated.value = true;

      print('✅ State updated - isAuthenticated: ${isAuthenticated.value}');
      print('✅ User object set:');
      print('   - user.value != null: ${user.value != null}');
      print('   - userName: ${userName}');
      print('   - userEmail: ${userEmail}');
      print('   - avatarUrl: ${avatarUrl}');
      print('   - trustScore: ${trustScore}');
      print('   - userRoles: ${userRoles}');

      // Persist to storage
      _storage.write('accessToken', authResponse.accessToken);
      _storage.write('user', jsonEncode(authResponse.user.toJson()));

      print('✅ Data persisted to storage');

      await GraphQLClientInstance.setToken(authResponse.accessToken);

      print('🔐 Login success: ${authResponse.user.name}');
      print('✅ UI should update now! All Obx widgets should react to user changes.');
    } catch (e, stackTrace) {
      print('❌ Login failed: $e');
      print('Stack trace: $stackTrace');

      // Show error to user
      Get.snackbar(
        'Login Failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.error.withValues(alpha: 0.8),
        colorText: AppTheme.neutral100,
      );
    } finally {
      isLoading.value = false;
      print('🔵 isLoading set to false');
    }
  }

  void logout() {
    _googleSignIn.signOut();
    _storage.erase();

    isAuthenticated.value = false;
    user.value = null;
    accessToken.value = '';

    GraphQLClientInstance.init();
  }
}
