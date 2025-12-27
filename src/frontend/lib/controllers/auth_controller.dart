import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/auth_service.dart';
import '../services/graphql_client.dart';

class AuthController extends GetxController {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: dotenv.env['GOOGLE_CLIENT_ID'],
  );

  final _storage = GetStorage();
  final _authService = AuthService();

  final isAuthenticated = false.obs;
  final avatarUrl = ''.obs;
  final accessToken = ''.obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadAuthData();
  }

  void _loadAuthData() {
    final storedToken = _storage.read<String>('accessToken');

    if (storedToken == null || storedToken.isEmpty) return;

    accessToken.value = storedToken;
    avatarUrl.value = _storage.read<String>('avatarUrl') ?? '';
    isAuthenticated.value = true;

    GraphQLClientInstance.setToken(storedToken);

    print('✅ Auth restored');
  }

  Future<void> signInWithGoogle() async {
    try {
      isLoading.value = true;

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Missing Google ID token');
      }

      final response = await _authService.verifyGoogleToken(idToken);

      accessToken.value = response['access'];
      avatarUrl.value = response['user']['avatar'] ?? '';
      isAuthenticated.value = true;

      _storage.write('accessToken', accessToken.value);
      _storage.write('avatarUrl', avatarUrl.value);

      await GraphQLClientInstance.setToken(accessToken.value);

      print('🔐 Login success');
    } catch (e) {
      print('❌ Login failed: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void logout() {
    _googleSignIn.signOut();
    _storage.erase();

    isAuthenticated.value = false;
    avatarUrl.value = '';
    accessToken.value = '';

    GraphQLClientInstance.init();
  }
}
