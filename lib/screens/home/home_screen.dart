import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:runam/app/theme.dart';
import '../../components/errand_card.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:geotypes/geotypes.dart' as geojson;

class UnauthenticatedHomeScreen extends StatefulWidget {
  const UnauthenticatedHomeScreen({super.key});

  static const String routeName = "unauthenticated-home";
  static const String path = "/unauthenticated-home";

  @override
  State<UnauthenticatedHomeScreen> createState() =>
      _UnauthenticatedHomeScreenState();
}

class _UnauthenticatedHomeScreenState
    extends State<UnauthenticatedHomeScreen> {
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  mapbox.MapboxMap? mapboxMap;

  _onMapCreated(mapbox.MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    mapboxMap.location.updateSettings(mapbox.LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
      puckBearingEnabled: true,
    ));
  }


  mapbox.CameraOptions? _cameraOptions;

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  Future<void> _initMap() async {
    // 1️⃣ Set Mapbox token
    final token = dotenv.env['MAPBOX_PUBLIC_TOKEN'];
    if (token == null || token.isEmpty) {
      throw Exception('MAPBOX_PUBLIC_TOKEN not found in .env');
    }
    mapbox.MapboxOptions.setAccessToken(token);

    // 2️⃣ Request location permission
    geo.LocationPermission permission =
    await geo.Geolocator.requestPermission();

    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever) {
      return;
    }

    // 3️⃣ Get user location (new API – no deprecated accuracy)
    final geo.Position position =
    await geo.Geolocator.getCurrentPosition(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
      ),
    );

    // 4️⃣ Update camera safely
    if (!mounted) return;

    setState(() {
      _cameraOptions = mapbox.CameraOptions(
        center: mapbox.Point(
          coordinates: mapbox.Position(
            position.longitude,
            position.latitude,
          ),
        ),
        zoom: 14.0,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.neutral100,
      body: Stack(
        children: [
          // 🗺️ REAL MAPBOX MAP
          Positioned.fill(
            // top: 0,
            // left: 0,
            // right: 0,
            // height: MediaQuery.of(context).size.height * 0.45,
            child: _cameraOptions == null
                ? const Center(child: CircularProgressIndicator())
                : mapbox.MapWidget(
              onMapCreated: _onMapCreated,
              cameraOptions: _cameraOptions!,
              styleUri: mapbox.MapboxStyles.MAPBOX_STREETS,
            ),
          ),

          // 🔝 Header overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your preferred location',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.primary700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(IconsaxPlusLinear.edit,
                      color: AppTheme.primary700),
                  Image.asset(
                    'assets/images/ghost.png',
                    width: 50,
                    height: 50,
                  ),
                ],
              ),
            ),
          ),

          // ⬇️ Draggable Bottom Sheet
          DraggableScrollableSheet(
            initialChildSize: 0.55, // Matches your original height percentage
            controller: _sheetController,
            minChildSize: 0.3,     // The height when collapsed
            maxChildSize: 0.9,     // How far up it can go
            snap: true,            // Makes it snap to the sizes defined
            snapSizes: const [0.3, 0.55, 0.9],
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: AppTheme.secondary500,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                ),
                child: SingleChildScrollView(
                  controller: scrollController, // Crucial for dragging logic
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Optional: Add a grab handle indicator
                        Center(
                          child: Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                              color: AppTheme.primary700.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Sample errand',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(color: AppTheme.primary700),
                        ),
                        const SizedBox(height: 15),
                        const ErrandCard(),

                        // Add more sample content to make scrolling obvious
                        const SizedBox(height: 20),
                        const ErrandCard(),

                        const SizedBox(height: 40),
                        Center(
                          child: RichText(
                            text: const TextSpan(
                              text: 'Already have an account? ',
                              style: TextStyle(color: AppTheme.primary700),
                              children: [
                                TextSpan(
                                  text: 'Login',
                                  style: TextStyle(
                                    color: AppTheme.links,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20), // Bottom padding for scroll
                      ],
                    ),
                  ),
                ),
              );
            },
          ),


          // 🔘 Floating CTA
          AnimatedBuilder(
              animation: _sheetController,
              builder: (context, child) {
                // Get current size (defaults to initialChildSize if not yet attached)
                double currentSize = _sheetController.isAttached
                    ? _sheetController.size
                    : 0.55;

                // 1. Calculate Position: Move it exactly above the sheet
                // currentSize is % of screen. 1.0 - currentSize is the gap at the top.
                // We subtract an extra 60-70 pixels to sit comfortably above the lip.
                double topPosition = MediaQuery.sizeOf(context).height * (1.0 - currentSize) - 20;

                // 2. Animation Logic: Is it at the top (0.9)?
                bool isExpanded = currentSize >= 0.85;

                return Positioned(
                  top: topPosition,
                  right: 20,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: isExpanded ? 56 : 220, // Shrink to circle width
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.neutral100,
                        elevation: 4,
                        padding: EdgeInsets.zero, // Important for centering icon
                        side: const BorderSide(color: AppTheme.primary700, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(IconsaxPlusLinear.profile, color: AppTheme.primary700),
                          // 3. Animate the label disappearance
                          ClipRect(
                            child: AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              child: SizedBox(
                                width: isExpanded ? 0 : null,
                                child: Padding(
                                  padding: EdgeInsets.only(left: isExpanded ? 0 : 8.0),
                                  child: Text(
                                    isExpanded ? "" : 'Create an account',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(color: AppTheme.primary700, fontWeight: FontWeight.bold),
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
                  ),
                );
            }
          ),
        ],
      ),
    );
  }
}
