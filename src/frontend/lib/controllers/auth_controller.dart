import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/auth_service.dart';

class AuthController extends GetxController {
  final AuthService _authService = AuthService();
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  var isAuthenticated = false.obs;
  var avatarUrl = ''.obs;
  var accessToken = ''.obs;

  Future<void> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) throw Exception("No ID token");

      final response = await _authService.verifyGoogleToken(idToken);

      accessToken.value = response['access'];
      avatarUrl.value = googleUser.photoUrl ?? '';
      isAuthenticated.value = true;

      Get.back();
    } catch (e) {
      Get.snackbar("Login failed", e.toString());
    }
  }

  void logout() {
    _googleSignIn.signOut();
    isAuthenticated.value = false;
    avatarUrl.value = '';
    accessToken.value = '';
  }
}


