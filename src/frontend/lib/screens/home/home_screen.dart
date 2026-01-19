import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import '../../app/theme.dart';
import '../../components/errand_card.dart';
import '../../controllers/auth_controller.dart';
import '../../features/errand/screens/add_errand.dart';
import '../profile/profile_screen.dart';
import '../../features/errand/controllers/errand_controllers.dart';
import '../../controllers/role_controller.dart';
import '../../controllers/location_controller.dart';

class HomeScreen extends StatefulWidget {
  static const String routeName = "home";
  static const String path = "/home";

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AuthController authController;
  late final ErrandController errandController;
  final RoleController roleController = Get.put(RoleController());
  final DraggableScrollableController _sheetController =
  DraggableScrollableController();

  mapbox.MapboxMap? mapboxMap;
  mapbox.CameraOptions? _cameraOptions;

  bool _isFollowingUser = true;
  late final LocationController _locationController;

  @override
  void initState() {
    super.initState();
    authController = Get.find<AuthController>();
    errandController = Get.find<ErrandController>();
    _locationController = Get.find<LocationController>();
    _startTrackingLocation();
    // React to location controller changes
    ever(_locationController.locationMode, (_) => _onLocationPayloadChanged());
    ever(_locationController.currentPosition, (_) => _onLocationPayloadChanged());
    ever(_locationController.staticPlace, (_) => _onLocationPayloadChanged());
    // Synchronise la localisation utilisateur à chaque montage de l'écran
    WidgetsBinding.instance.addPostFrameCallback((_) {
      authController.syncLocation();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _startTrackingLocation() async {
    final token = dotenv.env['MAPBOX_PUBLIC_TOKEN'];
    if (token == null) return;
    mapbox.MapboxOptions.setAccessToken(token);

    // Use LocationController as the source of truth. If it already has a payload, use it to center the map.
    final payload = _locationController.toPayload();
    if (payload.isNotEmpty) {
      final lat = (payload['latitude'] as num).toDouble();
      final lng = (payload['longitude'] as num).toDouble();
      setState(() {
        _cameraOptions = mapbox.CameraOptions(
          center: mapbox.Point(coordinates: mapbox.Position(lng, lat)),
          zoom: 15.0,
        );
      });
    }
  }

  // Called when LocationController publishes a new payload (STATIC or DEVICE)
  void _onLocationPayloadChanged() {
    if (!mounted) return;
    final payload = _locationController.toPayload();
    if (payload.isEmpty) return;

    final lat = (payload['latitude'] as num).toDouble();
    final lng = (payload['longitude'] as num).toDouble();

    if (mapboxMap == null) {
      // Update initial camera options so the MapWidget starts centered
      setState(() {
        _cameraOptions = mapbox.CameraOptions(
          center: mapbox.Point(coordinates: mapbox.Position(lng, lat)),
          zoom: 15.0,
        );
      });
      return;
    }

    // Animate camera to the new position
    _isFollowingUser = true; // consider following after a location change
    mapboxMap!.flyTo(
      mapbox.CameraOptions(
        center: mapbox.Point(coordinates: mapbox.Position(lng, lat)),
        zoom: 15,
      ),
      mapbox.MapAnimationOptions(duration: 800),
    );
    setState(() {});
  }

  Future<void> _recenterMap() async {
    if (mapboxMap == null) return;

    final payload = _locationController.toPayload();
    if (payload.isEmpty) return;
    final lat = (payload['latitude'] as num).toDouble();
    final lng = (payload['longitude'] as num).toDouble();
    mapboxMap!.flyTo(
      mapbox.CameraOptions(
        center: mapbox.Point(coordinates: mapbox.Position(lng, lat)),
        zoom: 15,
      ),
      mapbox.MapAnimationOptions(duration: 600),
    );

    setState(() => _isFollowingUser = true);
  }

  void _onMapCreated(mapbox.MapboxMap map) {
    mapboxMap = map;
    map.location.updateSettings(
      mapbox.LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
      ),
    );
    // If a payload exists, animate to it when the map is ready
    Future.microtask(() => _onLocationPayloadChanged());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.neutral100,
      body: Stack(
        children: [
          mapbox.MapWidget(
            cameraOptions: _cameraOptions,
            onMapCreated: _onMapCreated,
            onCameraChangeListener: (camera) {
              if (_isFollowingUser) {
                _isFollowingUser = false;
                setState(() {});
              }
            },
          ),

          if (!_isFollowingUser)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 80,
              right: 20,
              child: FloatingActionButton.small(
                backgroundColor: AppTheme.neutral100,
                onPressed: _recenterMap,
                child: const Icon(Icons.my_location,
                    color: AppTheme.primary700),
              ),
            ),

          /// HEADER
          SafeArea(
            child: Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your preferred location',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(
                        color: AppTheme.primary700,
                        fontWeight: FontWeight.bold),
                  ),
                  const Icon(IconsaxPlusLinear.edit,
                      color: AppTheme.primary700),

                  /// 🔑 AVATAR – reactive & safe
                  Obx(() {
                    final avatar = authController.avatarUrl;

                    return GestureDetector(
                      onTap: () =>
                          context.pushNamed(ProfileScreen.routeName),
                      child: Hero(
                        tag: 'ghost-avatar-hero',
                        child: CircleAvatar(
                          backgroundImage: avatar.isNotEmpty
                              ? NetworkImage(avatar)
                              : const AssetImage(
                              'assets/images/ghost.png')
                          as ImageProvider,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          /// DRAGGABLE SHEET
          DraggableScrollableSheet(
            initialChildSize: 0.3,
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
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min, // Important: shrink-wrap content
                    children: [
                      // Top drag indicator
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppTheme.primary700.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // TITLE
                      Obx(() => Text(
                        authController.isAuthenticated.value
                            ? 'Recent errands'
                            : 'Sample errand',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: AppTheme.primary700),
                      )),
                      const SizedBox(height: 15),

                      // CONTENT
                      Obx(() {
                        if (errandController.isLoading.value) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final errands = errandController.errands;

                        if (errands.isEmpty) {
                          return _buildEmptyState(); // Authenticated but no errands
                        }

                        // Display errands as a Column with shrink-wrap
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(errands.length, (index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: ErrandCard(errand: errands[index]),
                            );
                          }),
                        );
                      }),

                      const SizedBox(height: 40),

                      // FOOTER LOGIN PROMPT
                      Obx(() {
                        if (authController.isAuthenticated.value) {
                          return const SizedBox.shrink();
                        }
                        return Center(
                          child: GestureDetector(
                            onTap: () => authController.login(),
                            child: const Text(
                              'Already have an account? Log in',
                              style: TextStyle(
                                color: AppTheme.primary700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),



          Obx(() => authController.isRunnerActive ? const SizedBox.shrink() : _buildMovingFloatingCTA()),



          /// GLOBAL LOADING OVERLAY
          Obx(() {
            if (!authController.isLoading.value) {
              return const SizedBox.shrink();
            }
            return Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            );
          }),
        ],
      ),
      // If you have a floatingActionButton that depends on roleController, wrap it in Obx here
      // floatingActionButton: Obx(() => roleController.isRunnerActive ? null : _buildFloatingCTA()),
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
                    authController.login();
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
              ));
            }));
          });
  }

  void _handleCreateErrand() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => const AddErrandScreen()),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset('assets/images/empty-box.png', height: 150, fit: BoxFit.contain),
          const SizedBox(height: 16),
          Text(
            "No errands yet",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.primary700, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Don't be shy make a request",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.primary700, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
