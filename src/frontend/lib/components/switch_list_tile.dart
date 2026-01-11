import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:runam/app/theme.dart';
import '../controllers/auth_controller.dart';
import '../controllers/location_controller.dart';
import '../models/place_models.dart';
import '../services/mapbox_service.dart';

class ProfileSwitchListTile extends StatefulWidget {
  final bool isAuth;

  const ProfileSwitchListTile({super.key, required this.isAuth});

  @override
  State<ProfileSwitchListTile> createState() => _ProfileSwitchListTileState();
}

class _ProfileSwitchListTileState extends State<ProfileSwitchListTile> {
  late final AuthController authController;
  final locationController = Get.find<LocationController>();
  final mapboxService = MapboxService();

  final TextEditingController _searchController = TextEditingController();
  final RxList<Place> _results = <Place>[].obs;


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
          trailing: Obx(() {
              return Switch.adaptive(
                value: locationController.locationMode.value == LocationMode.device,
                onChanged: (value) {
                  value
                      ? locationController.switchToDevice()
                      : locationController.locationMode.value = LocationMode.static;
                },
              );
            }
          ),
        ),

        /// 🔥 Only Obx where it actually reacts
        Obx(() {
          final isBuyer = authController.userRoles.contains('Buyer');

          return AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: (widget.isAuth && !isBuyer) ||
                locationController.locationMode.value != LocationMode.static
                ? const SizedBox.shrink()
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                TextField(
                  controller: _searchController,
                  onChanged: (query) async {
                    if (query.length < 3) {
                      _results.clear();
                      return;
                    }

                    final places = await mapboxService.searchPlaces(query);
                    _results.assignAll(places);
                  },
                  decoration: InputDecoration(
                    hintText: 'Enter your preferred location',
                    suffixIcon: const Icon(IconsaxPlusLinear.gps),
                    filled: true,
                    fillColor: const Color(0xFFF8F9FA),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                /// Autocomplete results (already wired)
                Obx(() {
                  if (_results.isEmpty) return const SizedBox.shrink();

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final place = _results[index];

                      return ListTile(
                        leading: const Icon(Icons.location_on),
                        title: Text(place.name),
                        subtitle: Text(place.formattedAddress),
                        onTap: () {
                          locationController.switchToStatic(place);
                          authController.syncLocation();

                          _searchController.text = place.name;
                          _results.clear();
                          FocusScope.of(context).unfocus();
                        },
                      );
                    },
                  );
                }),
              ],
            ),
          );

        }),

        const SizedBox(height: 8),

        /// 🔥 Clean reactive text
        Obx(() {
          if (_results.isEmpty) return const SizedBox.shrink();

          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _results.length,
            itemBuilder: (context, index) {
              final place = _results[index];

              return ListTile(
                leading: const Icon(Icons.location_on),
                title: Text(place.name),
                subtitle: Text(place.formattedAddress),
                onTap: () {
                  // ✅ THIS IS WHERE onTap GOES
                  locationController.switchToStatic(place);

                  authController.syncLocation();

                  _searchController.text = place.name;
                  _results.clear();
                  FocusScope.of(context).unfocus();
                },
              );
            },
          );
        }),


        const SizedBox(height: 16),
      ],
    );
  }
}