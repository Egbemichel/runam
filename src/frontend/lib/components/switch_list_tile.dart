import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:runam/app/theme.dart';
import '../controllers/auth_controller.dart';

class ProfileSwitchListTile extends StatefulWidget {
  final bool isAuth;

  const ProfileSwitchListTile({super.key, required this.isAuth});

  @override
  State<ProfileSwitchListTile> createState() => _ProfileSwitchListTileState();
}

class _ProfileSwitchListTileState extends State<ProfileSwitchListTile> {
  bool _useCurrentLocation = false;
  late final AuthController authController;

  @override
  void initState() {
    super.initState();
    authController = Get.find<AuthController>();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Use your current location',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.primary700,
              fontWeight: FontWeight.bold,
            ),
          ),
          trailing: Switch.adaptive(
            value: _useCurrentLocation,
            activeColor: AppTheme.primary700,
            onChanged: (value) {
              setState(() => _useCurrentLocation = value);
            },
          ),
        ),

        /// 🔥 Only Obx where it actually reacts
        Obx(() {
          final isBuyer = authController.userRoles.contains('Buyer');

          return AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _useCurrentLocation || (widget.isAuth && !isBuyer)
                ? const SizedBox.shrink()
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Enter your preferred location',
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                    suffixIcon: const Icon(
                      IconsaxPlusLinear.gps,
                      color: Colors.grey,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8F9FA),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        }),

        const SizedBox(height: 8),

        /// 🔥 Clean reactive text
        Obx(() {
          final isRunner = authController.userRoles.contains('Runner');

          return Text(
            widget.isAuth && isRunner
                ? "Buyers use this location to find nearby runners. Turning it off means no errands coming your way."
                : "This location is the same which runners will deliver to and get paid at for round-trip errands.",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              height: 1.4,
            ),
          );
        }),

        const SizedBox(height: 16),
      ],
    );
  }
}