import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:get/get.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../../app/theme.dart';
import '../../../services/errand_polling_service.dart';
import '../../../controllers/location_controller.dart';
import '../../../graphql/errand_queries.dart';

class ErrandSearchingScreen extends StatefulWidget {
  final String? errandId;
  final List<Map<String, dynamic>>? runners;

  const ErrandSearchingScreen({
    super.key,
    required this.errandId,
    this.runners,
  });

  static const String routeName = 'errand-searching';
  static const String path = '/errand-searching';

  @override
  State<ErrandSearchingScreen> createState() => _ErrandSearchingState();
}

class _ErrandSearchingState extends State<ErrandSearchingScreen>
    with SingleTickerProviderStateMixin {

  // Services
  late ErrandPollingService _pollingService;
  StreamSubscription? _pollingSub;

  // Controllers
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  late AnimationController _loaderController;

  // Mapbox
  mapbox.MapboxMap? mapboxMap;
  mapbox.CameraOptions? _cameraOptions;
  late final LocationController _locationController;

  // Runners
  final Map<String, Offset> _runnerScreenPositions = {};
  List<Map<String, dynamic>> _runners = [];

  // Visual Constants
  final Color kCyanSheetColor = const Color(0xFF9EF6FF);
  final Color kPrimaryPurple = const Color(0xFF8B6BFF);
  final Color kDarkText = const Color(0xFF1A2E4D);

  // Polling state
  bool _pollingStarted = false;

  @override
  void initState() {
    super.initState();
    _loaderController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    // Initialize runners from widget
    if (widget.runners != null) {
      _runners = List.from(widget.runners!);
    }

    _locationController = Get.find<LocationController>();

    // Setup reactive location updates
    ever(_locationController.locationMode, (_) => _onLocationPayloadChanged());
    ever(_locationController.currentPosition, (_) => _onLocationPayloadChanged());
    ever(_locationController.staticPlace, (_) => _onLocationPayloadChanged());

    _initializeMap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_pollingStarted) {
      _startPolling();
      _pollingStarted = true;
    }
  }

  Future<void> _initializeMap() async {
    final token = dotenv.env['MAPBOX_PUBLIC_TOKEN'];
    if (token == null) return;

    mapbox.MapboxOptions.setAccessToken(token);

    // Use LocationController for initial position
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

  void _startPolling() {
    if (widget.errandId == null) return;

    final client = GraphQLProvider.of(context).value;

    _pollingService = ErrandPollingService(client: client);

    _pollingService.startPolling(
      errandId: widget.errandId!,
      query: errandStatusQuery,
      interval: const Duration(seconds: 3),
    );

    _pollingSub = _pollingService.events.listen(_handlePollingEvent);
  }

  void _handlePollingEvent(Map<String, dynamic> event) {
    if (!mounted) return;

    debugPrint('[Searching] Event: ${event['type']}');

    final data = event['data'] as Map<String, dynamic>?;
    if (data == null) return;

    final status = data['status'] as String?;

    // Update runners if provided
    if (data['nearbyRunners'] is List) {
      setState(() {
        _runners = List<Map<String, dynamic>>.from(
            (data['nearbyRunners'] as List).map((r) => Map<String, dynamic>.from(r as Map))
        );
      });
      _updateAllRunnerScreenPositions();
    }

    // Handle status changes
    if (status == 'ACCEPTED' || status == 'IN_PROGRESS') {
      _navigateToInProgress(data);
    } else if (status == 'EXPIRED') {
      _handleExpired();
    }
  }

  void _navigateToInProgress(Map<String, dynamic> errandData) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Runner accepted your errand!'),
        backgroundColor: Colors.green,
      ),
    );

    // Navigate to in-progress screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ErrandInProgressScreen(errand: errandData),
      ),
    );
  }

  void _handleExpired() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No runner accepted your errand'),
        backgroundColor: Colors.orange,
      ),
    );

    Navigator.pop(context);
  }

  @override
  void dispose() {
    _pollingSub?.cancel();
    _pollingService.dispose();
    _loaderController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  void _onMapCreated(mapbox.MapboxMap map) {
    mapboxMap = map;
    map.location.updateSettings(
      mapbox.LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        pulsingColor: kPrimaryPurple.toARGB32(),
      ),
    );
    Future.microtask(() => _onLocationPayloadChanged());
  }

  void _onLocationPayloadChanged() {
    if (!mounted) return;
    final payload = _locationController.toPayload();
    if (payload.isEmpty) return;

    final lat = (payload['latitude'] as num).toDouble();
    final lng = (payload['longitude'] as num).toDouble();

    if (mapboxMap == null) {
      setState(() {
        _cameraOptions = mapbox.CameraOptions(
          center: mapbox.Point(coordinates: mapbox.Position(lng, lat)),
          zoom: 14.5,
        );
      });
      return;
    }

    mapboxMap!.flyTo(
      mapbox.CameraOptions(
        center: mapbox.Point(coordinates: mapbox.Position(lng, lat)),
        zoom: 14.5,
      ),
      mapbox.MapAnimationOptions(duration: 700),
    );

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _updateAllRunnerScreenPositions();
    });
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
        debugPrint('[Searching] Position conversion failed: $e');
      }
    }

    if (mounted) {
      setState(() {
        _runnerScreenPositions.addAll(newPositions);
      });
    }
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
              onCameraChangeListener: (camera) => _updateAllRunnerScreenPositions(),
            )
          else
            const Center(child: CircularProgressIndicator()),

          // 2. Pulsing Radar Effect (Added Here)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: AnimatedBuilder(
                  animation: _loaderController,
                  builder: (context, child) {
                    return Container(
                      width: 300 * _loaderController.value,
                      height: 300 * _loaderController.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: kPrimaryPurple.withOpacity(1 - _loaderController.value),
                          width: 4,
                        ),
                        color: kPrimaryPurple.withOpacity((1 - _loaderController.value) * 0.2),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // 3. Runner Avatars Overlay
          ..._runners.map((runner) {
            final id = (runner['id'] ?? runner['userId'] ?? runner['runnerId'])?.toString() ?? '';
            final imageUrl = runner['imageUrl'] ?? 'https://i.pravatar.cc/150?u=$id';
            final pos = _runnerScreenPositions[id];

            if (pos == null) return const SizedBox.shrink();

            return AnimatedPositioned(
              key: ValueKey(id),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              left: pos.dx,
              top: pos.dy,
              child: AvatarPin(imageUrl: imageUrl),
            );
          }),

          // Back Button
          Positioned(
            top: MediaQuery.paddingOf(context).top + 10,
            left: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.primary700),
                  borderRadius: BorderRadius.circular(8),
                  color: AppTheme.neutral100,
                ),
                child: const Icon(IconsaxPlusLinear.arrow_left_1, size: 24),
              ),
            ),
          ),

          // Draggable Sheet
          DraggableScrollableSheet(
            initialChildSize: 0.45,
            minChildSize: 0.3,
            maxChildSize: 0.9,
            snap: true,
            snapSizes: const [0.3, 0.45, 0.9],
            controller: _sheetController,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: kCyanSheetColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag indicator
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: kDarkText.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Animated Loader
                      RotationTransition(
                        turns: _loaderController,
                        child: CustomPaint(
                          size: const Size(80, 80),
                          painter: LoaderIconPainter(color: kPrimaryPurple),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Title
                      Text(
                        "Finding the perfect runner for you",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: kDarkText,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Subtitle
                      Text(
                        "Give us a second",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: kDarkText,
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Show number of nearby runners
                      if (_runners.isNotEmpty)
                        Text(
                          "${_runners.length} nearby runner${_runners.length == 1 ? '' : 's'}",
                          style: TextStyle(
                            color: kDarkText.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                        ),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Helper Widgets
class AvatarPin extends StatelessWidget {
  final String imageUrl;
  const AvatarPin({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF8B6BFF), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 22,
              backgroundImage: NetworkImage(imageUrl),
              backgroundColor: Colors.grey[200],
            ),
          ),
        );
      },
    );
  }
}

class LoaderIconPainter extends CustomPainter {
  final Color color;
  LoaderIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double center = size.width / 2;
    final double radius = size.width / 2;
    final Rect rect = Rect.fromCircle(
      center: Offset(center, center),
      radius: radius,
    );

    canvas.drawArc(rect, 0.2, 5.5, false, paint);

    final Path arrowPath = Path();
    double arrowX = center + radius * math.cos(0.2);
    double arrowY = center + radius * math.sin(0.2);

    arrowPath.moveTo(arrowX - 10, arrowY + 15);
    arrowPath.lineTo(arrowX + 5, arrowY);
    arrowPath.lineTo(arrowX - 20, arrowY - 5);

    canvas.drawPath(arrowPath, paint);
    canvas.drawArc(rect, 5.9, 0.2, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Placeholder for in-progress screen
class ErrandInProgressScreen extends StatelessWidget {
  final Map<String, dynamic> errand;
  const ErrandInProgressScreen({super.key, required this.errand});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Errand in Progress')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Status: ${errand['status']}'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}