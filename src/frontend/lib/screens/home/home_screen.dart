// import 'dart:async'; // Added for StreamSubscription
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
// import 'package:geolocator/geolocator.dart' as geo;

import '../../app/theme.dart';
import '../../components/errand_card.dart';
import '../../controllers/auth_controller.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  static const String routeName = "home";
  static const String path = "/home";

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AuthController authController;
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    // Get the singleton instance of AuthController
    authController = Get.find<AuthController>();
  }

  // mapbox.MapboxMap? mapboxMap;
  // mapbox.CameraOptions? _cameraOptions;

  // 1. Stream logic variables
  // StreamSubscription<geo.Position>? _positionStream;
  // bool _isFollowingUser = true; // Flag to auto-center

  // @override
  // void initState() {
  //   super.initState();
  //   _startTrackingLocation();
  // }

  // @override
  // void dispose() {
  //   // 2. Always cancel streams to prevent memory leaks
  //   _positionStream?.cancel();
  //   super.dispose();
  // }

  // 3. Initialize and Start Streaming Location
  // Future<void> _startTrackingLocation() async {
  //   final token = dotenv.env['MAPBOX_PUBLIC_TOKEN'];
  //   if (token == null) return;
  //   mapbox.MapboxOptions.setAccessToken(token);
  //
  //   geo.LocationPermission permission = await geo.Geolocator.requestPermission();
  //   if (permission == geo.LocationPermission.denied || permission == geo.LocationPermission.deniedForever) return;
  //
  //   // Initial setup of camera
  //   final geo.Position initialPos = await geo.Geolocator.getCurrentPosition();
  //   setState(() {
  //     _cameraOptions = mapbox.CameraOptions(
  //       center: mapbox.Point(coordinates: mapbox.Position(initialPos.longitude, initialPos.latitude)),
  //       zoom: 15.0,
  //     );
  //   });
  //
  //   // START STREAMING
  //   _positionStream = geo.Geolocator.getPositionStream(
  //     locationSettings: const geo.LocationSettings(
  //       accuracy: geo.LocationAccuracy.high,
  //       distanceFilter: 5, // Update only if user moves 5 meters
  //     ),
  //   ).listen((geo.Position position) {
  //     if (_isFollowingUser && mapboxMap != null) {
  //       // Smoothly move camera to new location
  //       mapboxMap!.setCamera(mapbox.CameraOptions(
  //         center: mapbox.Point(coordinates: mapbox.Position(position.longitude, position.latitude)),
  //       ));
  //     }
  //   });
  // }

  // _onMapCreated(mapbox.MapboxMap mapboxMap) {
  //   this.mapboxMap = mapboxMap;
  //   mapboxMap.location.updateSettings(mapbox.LocationComponentSettings(
  //     enabled: true,
  //     pulsingEnabled: true,
  //   ));
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.neutral100,
      body: Stack(
        children: [
          // MAP SECTION
          // Positioned.fill(
          //   child: _cameraOptions == null
          //       ? const Center(child: CircularProgressIndicator())
          //       : Listener(
          //     // 4. If the user touches the map, stop auto-following
          //     onPointerDown: (_) => setState(() => _isFollowingUser = false),
          //     child: mapbox.MapWidget(
          //       onMapCreated: _onMapCreated,
          //       cameraOptions: _cameraOptions!,
          //       styleUri: mapbox.MapboxStyles.MAPBOX_STREETS,
          //     ),
          //   ),
          // ),

          // 5. RE-CENTER BUTTON (Only shows if user isn't following)
          // if (!_isFollowingUser)
          //   Positioned(
          //     top: MediaQuery.paddingOf(context).top + 80,
          //     right: 20,
          //     child: FloatingActionButton.small(
          //       backgroundColor: AppTheme.neutral100,
          //       onPressed: () => setState(() => _isFollowingUser = true),
          //       child: const Icon(Icons.my_location, color: AppTheme.primary700),
          //     ),
          //   ),

          // Header Overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Your preferred location', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppTheme.primary700, fontWeight: FontWeight.bold)),
                  const Icon(IconsaxPlusLinear.edit, color: AppTheme.primary700),
                  GestureDetector(
                    onTap: () => context.pushNamed(ProfileScreen.routeName),
                    child: Hero(
                      tag: 'ghost-avatar-hero',
                      child: Obx(() {
                        return CircleAvatar(
                          backgroundImage: authController.avatarUrl.value.isNotEmpty
                              ? NetworkImage(authController.avatarUrl.value)
                              : const AssetImage('assets/images/ghost.png') as ImageProvider,
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Draggable Sheet
          DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.3,
            maxChildSize: 0.9,
            snap: true,
            snapSizes: const [0.3, 0.55, 0.9],
            controller: _sheetController,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: AppTheme.secondary500,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: AppTheme.primary700.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 20),
                    Obx(() => Text(authController.isAuthenticated.value ? 'Recent errands' : 'Sample errand', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppTheme.primary700))),
                    const SizedBox(height: 15),
                    Obx(() {
                      final isAuth = authController.isAuthenticated.value;
                      return isAuth ? _buildEmptyState() : const ErrandCard();
                    }),
                    const SizedBox(height: 40),
                    Obx(() {
                      if (authController.isAuthenticated.value) {
                        return const SizedBox.shrink();
                      }
                      return Center(
                        child: RichText(
                          text: const TextSpan(
                            text: 'Already have an account? ',
                            style: TextStyle(color: AppTheme.primary700),
                            children: [
                              TextSpan(
                                text: 'Log in',
                                style: TextStyle(
                                  color: AppTheme.links,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),

          _buildMovingFloatingCTA(),
          Obx(() {
            if (!authController.isLoading.value) return const SizedBox.shrink();

            return Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.4),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // The Morphing CTA Logic
  Widget _buildMovingFloatingCTA() {
    return AnimatedBuilder(
      animation: _sheetController,
      builder: (context, child) {
        double currentSize = _sheetController.isAttached ? _sheetController.size : 0.55;
        double topPosition = MediaQuery.sizeOf(context).height * (1.0 - currentSize) - 20;
        bool isExpanded = currentSize >= 0.85;

        return Positioned(
          top: topPosition,
          right: 20,
          child: Obx(() {
            bool isAuth = authController.isAuthenticated.value;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: isExpanded ? 56 : 220,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  if (isAuth) {
                    _handleCreateErrand();
                  } else {
                    // ROLE 2: Unauthenticated - Trigger Login
                    authController.signInWithGoogle();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.neutral100,
                  elevation: 4,
                  padding: EdgeInsets.zero,
                  side: const BorderSide(color: AppTheme.primary700, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(isAuth ? IconsaxPlusLinear.add : IconsaxPlusLinear.profile, color: AppTheme.primary700, size: 32),
                    ClipRect(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        child: SizedBox(
                          width: isExpanded ? 0 : null,
                          child: Padding(
                            padding: EdgeInsets.only(left: isExpanded ? 0 : 8.0),
                            child: Text(
                              isExpanded ? "" : (isAuth ? "New errand" : "Create an account"),
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.primary700, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.fade,
                              softWrap: false,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // Add this helper method to your _HomeScreenState
  void _handleCreateErrand() {
    // For now, let's just show a snackbar or navigate
    print('🚀 Create Errand button pressed');

    // Future: context.pushNamed(CreateErrandScreen.routeName);
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        Image.asset('assets/images/empty-box.png', height: 150),
        Text("No errands yet", style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppTheme.primary700, fontWeight: FontWeight.bold)),
        Text("Don't be shy make a request", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.primary700, fontWeight: FontWeight.bold)),
      ],
    );
  }
}