// lib/screens/errand/errand_searching_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:get/get.dart';
import '../../../app/theme.dart';
import '../../../controllers/location_controller.dart';
import '../../../controllers/buyer_tracking_controller.dart';

class ErrandSearchingScreen extends StatefulWidget {
  final String? errandId;
  final List<Map<String, dynamic>>? runners;

  static const String routeName = "errand-searching";
  static const String path = '/errand-searching';

  const ErrandSearchingScreen({
    super.key,
    required this.errandId,
    this.runners,
  });

  @override
  State<ErrandSearchingScreen> createState() => _ErrandSearchingState();
}

class _ErrandSearchingState extends State<ErrandSearchingScreen> {
  // Mapbox & Location
  mapbox.MapboxMap? mapboxMap;
  mapbox.CameraOptions? _cameraOptions;
  late final LocationController _locationController;

  // Dependency Injection
  final BuyerTrackingController _statusController = Get.find<BuyerTrackingController>();

  // Runner Visuals
  final Map<String, Offset> _runnerScreenPositions = {};
  List<Map<String, dynamic>> _runners = [];

  @override
  void initState() {
    super.initState();
    _locationController = Get.find<LocationController>();
    if (widget.runners != null) _runners = List.from(widget.runners!);

    // Start the global tracking process.
    // Ensure the method name matches your Controller (startTracking or startPolling)
    if (widget.errandId != null) {
      _statusController.monitorErrand(widget.errandId!);
    }

    _initializeMap();
  }

  Future<void> _initializeMap() async {
    final token = dotenv.env['MAPBOX_PUBLIC_TOKEN'];
    if (token == null) return;
    mapbox.MapboxOptions.setAccessToken(token);

    final loc = _locationController.toPayload();
    if (loc.isNotEmpty) {
      final lat = (loc['latitude'] as num).toDouble();
      final lng = (loc['longitude'] as num).toDouble();
      setState(() {
        _cameraOptions = mapbox.CameraOptions(
          center: mapbox.Point(coordinates: mapbox.Position(lng, lat)),
          zoom: 14.5,
        );
      });
    }
  }

  void _onMapCreated(mapbox.MapboxMap map) {
    mapboxMap = map;
    _updateAllRunnerScreenPositions();
  }

  /// Projects the Lat/Lng of nearby runners into screen pixel offsets
  Future<void> _updateAllRunnerScreenPositions() async {
    if (mapboxMap == null || _runners.isEmpty) return;
    final Map<String, Offset> newPositions = {};

    for (final r in _runners) {
      final id = (r['id'] ?? r['userId'] ?? r['runnerId']).toString();
      final lat = (r['latitude'] ?? r['lat']) as num?;
      final lng = (r['longitude'] ?? r['lng']) as num?;

      if (id.isEmpty || lat == null || lng == null) continue;

      try {
        final screenPoint = await mapboxMap!.pixelForCoordinate(
            mapbox.Point(coordinates: mapbox.Position(lng.toDouble(), lat.toDouble()))
        );
        // Offset by half the avatar size (22) to center it on the coordinate
        newPositions[id] = Offset(screenPoint.x - 22, screenPoint.y - 22);
      } catch (e) {
        debugPrint('Position conversion failed for runner $id: $e');
      }
    }

    if (mounted) setState(() => _runnerScreenPositions.addAll(newPositions));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Map Layer
          if (_cameraOptions != null)
            mapbox.MapWidget(
              cameraOptions: _cameraOptions,
              onMapCreated: _onMapCreated,
              onCameraChangeListener: (_) => _updateAllRunnerScreenPositions(),
            )
          else
            const Center(child: CircularProgressIndicator()),

          // 2. Status Overlay - Reactive to the Global Controller
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Obx(() {
                  final status = _statusController.currentStatus.value;
                  // If status is 'ACCEPTED', the controller will navigate away automatically.
                  // We show 'RUNNER_FOUND' for the brief moment during transition if the DB updates.
                  final isFound = status == 'ACCEPTED' || status == 'IN_PROGRESS';

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isFound)
                          const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primary700
                            ),
                          ),
                        if (!isFound) const SizedBox(width: 12),
                        Text(
                          isFound ? 'Runner Found!' : 'Finding your Runner...',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary700
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),

          // 3. Runner Markers - Floating on top of the Map
          ..._runners.map((runner) {
            final id = (runner['id'] ?? runner['userId']).toString();
            final pos = _runnerScreenPositions[id];
            if (pos == null) return const SizedBox.shrink();

            return AnimatedPositioned(
              key: ValueKey(id),
              duration: const Duration(milliseconds: 500),
              left: pos.dx,
              top: pos.dy,
              child: AvatarPin(imageUrl: runner['imageUrl'] ?? ''),
            );
          }),
        ],
      ),
    );
  }
}

class AvatarPin extends StatelessWidget {
  final String imageUrl;
  const AvatarPin({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: CircleAvatar(
        radius: 20,
        backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
        child: imageUrl.isEmpty ? const Icon(Icons.person) : null,
      ),
    );
  }
}