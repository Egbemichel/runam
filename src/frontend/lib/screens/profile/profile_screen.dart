import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:runam/components/switch_list_tile.dart';
import '../../app/theme.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/role_controller.dart';
import '../../services/graphql_client.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static const String routeName = "profile";
  static const String path = '/profile';

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final AuthController authController;
  final RoleController roleController = Get.put(RoleController());

  @override
  void initState() {
    super.initState();
    authController = Get.find<AuthController>();

  }

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();
    return Obx(() {
      bool isAuth = authController.isAuthenticated.value;
      bool isRunner = authController.userRoles.contains('RUNNER');
      bool isRunnerActive = authController.isRunnerActive;
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          actions: [
            if (isAuth)
              IconButton(
                onPressed: () {
                  authController.logout();
                  Navigator.of(context).pop();
                },
                icon: const Icon(IconsaxPlusLinear.logout, color: Colors.red, size: 32),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          children: [
            _buildAvatarSection(isAuth),
            const SizedBox(height: 20),
            if (isAuth) _buildUserInfo(isRunnerActive),
            const SizedBox(height: 24),
            _buildLocationSection(isAuth),
            const SizedBox(height: 16),
            _buildMenuOptions(isAuth, isRunnerActive),
            const SizedBox(height: 24),
            _buildRoleFooter(isAuth, isRunner),
          ],
        ),
      );
    });
  }

  /// AVATAR
  Widget _buildAvatarSection(bool isAuth) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primary700, width: 4),
              ),
              child: Hero(
                tag: 'ghost-avatar-hero',
                child: CircleAvatar(
                  radius: 80,
                  backgroundColor: Colors.transparent,
                  backgroundImage: isAuth && authController.avatarUrl.isNotEmpty
                      ? NetworkImage(authController.avatarUrl)
                      : const AssetImage('assets/images/ghost_2.png') as ImageProvider,
                ),
              ),
            ),
            Positioned(
              bottom: -15,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.secondary500,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Row(
                  children: [
                    Image.asset(
                      isAuth ? 'assets/images/shield-tick.png' : 'assets/images/cancel.png',
                      width: 30,
                      height: 30,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isAuth ? '${authController.trustScore}/100' : "",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primary700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUserInfo(bool isRunner) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(authController.userName, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1A1A4E))),
            const SizedBox(width: 8),
            if (isRunner) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(border: Border.all(color: AppTheme.success), borderRadius: BorderRadius.circular(8)), child: const Text("verified", style: TextStyle(color: AppTheme.success, fontSize: 12))),
            const Icon(IconsaxPlusLinear.edit, color: AppTheme.primary700, size: 20),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.g_mobiledata, color: AppTheme.primary700),
            Text(authController.userEmail, style: const TextStyle(color: Color(0xFF1A1A4E))),
          ],
        ),
        Text(isRunner ? "Runner" : "Buyer", style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildLocationSection(bool isAuth) {
    return ProfileSwitchListTile(isAuth: isAuth);
  }

  Widget _buildMenuOptions(bool isAuth, bool isRunner) {
    return Column(
      children: [
        if (isAuth && !isRunner) _buildTile(IconsaxPlusLinear.card, "Payment methods", "cash"),
        if (isAuth) _buildTile(IconsaxPlusLinear.message, "Chats", null),
        _buildTile(IconsaxPlusLinear.shield, "Trust & Safety", null),
        _buildTile(IconsaxPlusLinear.people, "How buyers and runners interact", null),
      ],
    );
  }

  Widget _buildTile(IconData icon, String title, String? sub) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppTheme.primary700),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary700)),
      subtitle: sub != null ? Text(sub) : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.primary700),
    );
  }

  Widget _buildRoleFooter(bool isAuth, bool isRunner) {
    if (!isAuth) {
      return const Center(child: Text("logging in gives you many more settings and information", style: TextStyle(color: Colors.grey)));
    }
    if (isRunner) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Switch roles", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF5FDFF),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFE0E0FF)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => authController.switchRole("RUNNER"),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: authController.isRunnerActive == true ? const Color(0xFFE0E0FF) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          "Runner",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: authController.isRunnerActive == true ? const Color(0xFF8B5CF6) : const Color(0xFF1A1A4E),
                            fontFamily: authController.activeRole.value == UserRole.RUNNER ? 'Grandstander' : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => authController.switchRole("BUYER"),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: authController.isBuyerActive == true ? const Color(0xFFE0E0FF) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          "Buyer",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: authController.isBuyerActive == true ? const Color(0xFF8B5CF6) : const Color(0xFF1A1A4E),
                            fontFamily: authController.activeRole.value == UserRole.BUYER ? 'Grandstander' : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              authController.isRunnerActive == false
                  ? "No errands to post? Go run some!"
                  : "Exhausted? Let someone else do the work!",
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      );
    }
    return GestureDetector(
      onTap: () async {
        final client = GraphQLClientInstance.client;

        try {
          await authController.becomeRunner(client);
        } catch (_) {
          Get.snackbar("Error", "Could not become runner");
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5FDFF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.directions_run, color: AppTheme.primary700),
            SizedBox(width: 12),
            Text(
              "Earn as a runner",
              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary700),
            ),
            Spacer(),
            Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.primary700),
          ],
        ),
      ),
    );

  }


}