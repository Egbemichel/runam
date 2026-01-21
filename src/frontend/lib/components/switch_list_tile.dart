import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:runam/app/theme.dart';
import 'package:runam/controllers/auth_controller.dart';
import 'package:runam/controllers/location_controller.dart';
import 'package:runam/models/place_models.dart';
import 'package:runam/components/location_search_field.dart';

class ProfileSwitchListTile extends StatefulWidget {
  final bool isAuth;

  const ProfileSwitchListTile({super.key, required this.isAuth});

  @override
  State<ProfileSwitchListTile> createState() => _ProfileSwitchListTileState();
}

class _ProfileSwitchListTileState extends State<ProfileSwitchListTile> {
  static const String _tag = '🔄 [ProfileSwitchListTile]';

  late final AuthController authController;
  final locationController = Get.find<LocationController>();
  final TextEditingController _searchController = TextEditingController();
  Worker? _staticPlaceWorker; // Store worker reference to dispose later

  @override
  void initState() {
    super.initState();
    authController = Get.find<AuthController>();
    debugPrint('$_tag Initializing ProfileSwitchListTile...');

    // Load persisted static place into text field
    _loadStaticPlaceIntoTextField();

    // Listen for changes to static place and update text field
    // Store the worker reference so we can dispose it later
    _staticPlaceWorker = ever(locationController.staticPlace, (place) {
      debugPrint('$_tag Static place changed: ${place?.name}');
      // Check if widget is still mounted before updating controller
      if (mounted && place != null && _searchController.text != place.name) {
        _searchController.text = place.name;
        debugPrint('$_tag Updated text field with: ${place.name}');
      }
    });
  }

  void _loadStaticPlaceIntoTextField() {
    final staticPlace = locationController.staticPlace.value;
    if (staticPlace != null) {
      _searchController.text = staticPlace.name;
      debugPrint('$_tag Loaded static place into text field: ${staticPlace.name}');
    } else {
      debugPrint('$_tag No static place to load into text field');
    }
  }

  @override
  void dispose() {
    debugPrint('$_tag Disposing ProfileSwitchListTile...');
    // Dispose the worker FIRST to prevent callbacks to disposed controller
    _staticPlaceWorker?.dispose();
    _staticPlaceWorker = null;
    _searchController.dispose();
    super.dispose();
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
            final isDeviceMode = locationController.locationMode.value == LocationMode.device;
            debugPrint('$_tag Building switch - current mode: ${locationController.locationMode.value.name}');

            return Switch.adaptive(
              value: isDeviceMode,
              onChanged: (value) {
                debugPrint('$_tag Switch toggled: $value (device mode: $value)');
                if (value) {
                  debugPrint('$_tag User switching to DEVICE mode');
                  locationController.switchToDevice();
                  authController.syncLocation();
                  debugPrint('$_tag Syncing location to backend...');
                } else {
                  debugPrint('$_tag User switching to STATIC mode');
                  locationController.prepareStaticMode();
                }
              },
            );
          }),
        ),

        /// Location search field - only shown when in static mode
        Obx(() {
          final isBuyer = authController.userRoles.contains('BUYER');
          final isStaticMode = locationController.locationMode.value == LocationMode.static;
          final shouldShow = widget.isAuth && isBuyer && isStaticMode;

          debugPrint('$_tag Location search visibility check: isAuth=${widget.isAuth}, isBuyer=$isBuyer, isStaticMode=$isStaticMode, shouldShow=$shouldShow');

          return AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: !shouldShow
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      LocationSearchField(
                        controller: _searchController,
                        hintText: 'Enter your preferred location',
                        onPlaceSelected: (place) {
                          debugPrint('$_tag User selected place: ${place.name}');
                          debugPrint('$_tag Coordinates: lat=${place.latitude}, lng=${place.longitude}');
                          locationController.switchToStatic(place);
                          debugPrint('$_tag Syncing location to backend...');
                          authController.syncLocation();
                        },
                      ),
                    ],
                  ),
          );
        }),


        const SizedBox(height: 16),
      ],
    );
  }
}