import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:get/get.dart';
import '../../../app/theme.dart';
import '../../../controllers/location_controller.dart';
import '../../../controllers/buyer_errand_status_controller.dart'; // Import your new controller

class ErrandSearchingScreen extends StatefulWidget {
  final String? errandId;
  final List<Map<String, dynamic>>? runners;

  static const routeName = 'errand-searching';
  static const path = '/errand-searching';

  const ErrandSearchingScreen({
    super.key,
    required this.errandId,
    this.runners,
  });

  @override
  State<ErrandSearchingScreen> createState() => _ErrandSearchingState();
}

class _ErrandSearchingState extends State<ErrandSearchingScreen>
    with SingleTickerProviderStateMixin {

  // Controllers
  late AnimationController _loaderController;
  late final LocationController _locationController;
  final BuyerErrandStatusController _statusController = Get.find<BuyerErrandStatusController>();

  // Mapbox
  mapbox.MapboxMap? mapboxMap;
  mapbox.CameraOptions? _cameraOptions;

  // Runners (Visual state only)
  final Map<String, Offset> _runnerScreenPositions = {};
  List<Map<String, dynamic>> _runners = [];

  final Color kPrimaryPurple = const Color(0xFF8B6BFF);

  @override
  void initState() {
    super.initState();
    _loaderController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    if (widget.runners != null) {
      _runners = List.from(widget.runners!);
    }

    _locationController = Get.find<LocationController>();

    // Start Global Tracking if not already tracking
    if (widget.errandId != null) {
      _statusController.startTracking(widget.errandId!);
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

  Future<void> _updateAllRunnerScreenPositions() async {
    if (mapboxMap == null || _runners.isEmpty) return;
    final Map<String, Offset> newPositions = {};

    for (final r in _runners) {
      final id = (r['id'] ?? r['userId'] ?? r['runnerId'])?.toString() ?? '';
      final lat = (r['latitude'] ?? r['lat']) as num?;
      final lng = (r['longitude'] ?? r['lng']) as num?;

      if (id.isEmpty || lat == null || lng == null) continue;

      try {
        final screenPoint = await mapboxMap!.pixelForCoordinate(
            mapbox.Point(coordinates: mapbox.Position(lng.toDouble(), lat.toDouble()))
        );
        newPositions[id] = Offset(screenPoint.x - 22, screenPoint.y - 22);
      } catch (e) {
        debugPrint('Position conversion failed: $e');
      }
    }

    if (mounted) setState(() => _runnerScreenPositions.addAll(newPositions));
  }

  @override
  void dispose() {
    _loaderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Map
          if (_cameraOptions != null)
            mapbox.MapWidget(
              cameraOptions: _cameraOptions,
              onMapCreated: _onMapCreated,
              onCameraChangeListener: (camera) => _updateAllRunnerScreenPositions(),
            )
          else
            const Center(child: CircularProgressIndicator()),

          // 2. UI Overlay (Obx makes this reactive to the global status)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Obx(() {
                  // If global controller found a runner, show "Runner Found"
                  if (_statusController.isChecking.value && _runners.isEmpty) {
                    return const SizedBox(
                      width: 80, height: 80,
                      child: CircularProgressIndicator(strokeWidth: 4, color: AppTheme.primary700),
                    );
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      'Searching for runners...',
                      style: const TextStyle(color: AppTheme.primary700, fontWeight: FontWeight.bold),
                    ),
                  );
                }),
              ),
            ),
          ),

          // 3. Runner Avatars
          ..._runners.map((runner) {
            final id = (runner['id'] ?? runner['userId'])?.toString() ?? '';
            final pos = _runnerScreenPositions[id];
            if (pos == null) return const SizedBox.shrink();

            return AnimatedPositioned(
              key: ValueKey(id),
              duration: const Duration(milliseconds: 600),
              left: pos.dx, top: pos.dy,
              child: AvatarPin(imageUrl: runner['imageUrl'] ?? 'https://i.pravatar.cc/150?u=$id'),
            );
          }).toList(),
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
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: CircleAvatar(radius: 22, backgroundImage: NetworkImage(imageUrl)),
    );
  }
}