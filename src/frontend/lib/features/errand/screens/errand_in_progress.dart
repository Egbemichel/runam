import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:dotted_border/dotted_border.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../services/errand_service.dart';
import '../../../app/theme.dart';
import '../../../components/runam_slider.dart';
import '../../../app/router.dart';

class ErrandInProgressScreen extends StatefulWidget {
  final Map<String, dynamic> errand;
  final bool isRunner;

  static const String routeName = "errand-in-progress";
  static const String path = "/errand-in-progress";

  const ErrandInProgressScreen({
    super.key,
    required this.errand,
    this.isRunner = true,
  });

  @override
  State<ErrandInProgressScreen> createState() => _ErrandInProgressScreenState();
}

class _ErrandInProgressScreenState extends State<ErrandInProgressScreen> {
  mapbox.MapboxMap? mapboxMap;
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  // Track checked state for each task
  late List<bool> _checkedStates;

  // Image proof
  File? _proofImage;
  bool _isUploading = false;

  // Avatar overlay positions (screen coords)
  final Map<String, Offset> _avatarPositions = {};

  // Errand service
  final ErrandService _errandService = ErrandService();

  // --- Data Helpers ---
  String get userName =>
      widget.isRunner
          ? (widget.errand['userName'] ?? widget.errand['requester']?['name'] ??
          widget.errand['requester']?['firstName'] ?? "Client")
          : (widget.errand['runnerName'] ?? "Your Runner");

  String get avatarUrl =>
      widget.isRunner
          ? (widget.errand['userAvatar'] ??
          widget.errand['requester']?['avatar'] ?? widget.errand['imageUrl'] ??
          "")
          : (widget.errand['runnerAvatar'] ??
          widget.errand['runner']?['avatar'] ?? "");

  double get totalPrice {
    // Try backend explicit fields first
    final priceRaw = widget.errand['totalPrice'] ??
        widget.errand['quoted_total_price'] ?? widget.errand['price'] ??
        widget.errand['errandValue'];
    double parsed = 0.0;
    if (priceRaw != null) {
      if (priceRaw is num) {
        parsed = priceRaw.toDouble();
      } else {
        parsed = double.tryParse(priceRaw.toString()) ?? 0.0;
      }
    }
    // If backend didn't supply, compute from tasks
    if (parsed <= 0) {
      try {
        parsed = tasks.fold<double>(0.0, (sum, t) {
          final p = t['price'] ?? t['amount'] ?? 0;
          if (p is num) return sum + p.toDouble();
          final pv = double.tryParse(p?.toString() ?? '0') ?? 0.0;
          return sum + pv;
        });
      } catch (_) {
        parsed = parsed;
      }
    }
    return parsed;
  }

  List<dynamic> get tasks => widget.errand['tasks'] ?? [];

  // --- Location helpers ---
  Map<String, dynamic>? get buyerLoc =>
      widget.errand['goTo'] ?? widget.errand['go_to'];

  Map<String, dynamic>? get runnerLoc =>
      widget.errand['runnerLocation'] ?? widget.errand['runner_location'] ??
          widget.errand['runnerLoc'];

  String? get runnerAvatar =>
      widget.errand['runnerAvatar'] ?? widget.errand['runner']?['avatar'];

  String? get buyerAvatar =>
      widget.errand['userAvatar'] ?? widget.errand['requester']?['avatar'] ??
          widget.errand['imageUrl'];

  // Trust scores
  int get buyerTrustScore {
    final raw = widget.errand['userTrustScore'] ?? widget.errand['userTrust'] ?? widget.errand['requester']?['trust_score'] ?? 0;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '0') ?? 0;
  }

  int get runnerTrustScore {
    final raw = widget.errand['runnerTrustScore'] ?? widget.errand['runnerTrust'] ?? widget.errand['runner']?['trust_score'] ?? 0;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '0') ?? 0;
  }

  // --- Distance ---
  double? get _distanceMeters {
    final b = buyerLoc;
    final r = runnerLoc;
    if (b == null || r == null) return null;
    final lat1 = (b['latitude'] ?? b['lat'])?.toDouble();
    final lon1 = (b['longitude'] ?? b['lng'])?.toDouble();
    final lat2 = (r['latitude'] ?? r['lat'])?.toDouble();
    final lon2 = (r['longitude'] ?? r['lng'])?.toDouble();
    if ([lat1, lon1, lat2, lon2].any((v) => v == null)) return null;
    return _haversine(lat1!, lon1!, lat2!, lon2!);
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0; // Earth radius in meters
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180.0);

  String _formatDistanceMessage() {
    final d = _distanceMeters;
    if (d == null) return "Runner location not available";
    if (d < 1000) return "Runner is ${(d).toStringAsFixed(0)} m away";
    return "Runner is ${(d / 1000).toStringAsFixed(1)} km away";
  }

  // --- Avatar overlay helpers ---
  Future<void> _updateAvatarPositions() async {
    if (mapboxMap == null) return;
    try {
      final buyer = buyerLoc;
      final runner = runnerLoc;
      final Map<String, Offset> positions = {};
      if (buyer != null) {
        final lat = (buyer['latitude'] ?? buyer['lat'])?.toDouble();
        final lng = (buyer['longitude'] ?? buyer['lng'])?.toDouble();
        if (lat != null && lng != null) {
          final screen = await mapboxMap!.pixelForCoordinate(
              mapbox.Point(coordinates: mapbox.Position(lng, lat)));
          positions['buyer'] = Offset(screen.x - 24, screen.y - 48);
        }
      }
      if (runner != null) {
        final lat = (runner['latitude'] ?? runner['lat'])?.toDouble();
        final lng = (runner['longitude'] ?? runner['lng'])?.toDouble();
        if (lat != null && lng != null) {
          final screen = await mapboxMap!.pixelForCoordinate(
              mapbox.Point(coordinates: mapbox.Position(lng, lat)));
          positions['runner'] = Offset(screen.x - 24, screen.y - 48);
        }
      }
      if (mounted) setState(() => _avatarPositions.addAll(positions));
    } catch (e) {
      debugPrint('[_updateAvatarPositions] error: $e');
    }
  }

  Widget _buildAvatarOverlay(String key, String? imageUrl) {
    final pos = _avatarPositions[key];
    if (pos == null) return const SizedBox.shrink();
    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: Column(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                ? NetworkImage(imageUrl)
                : const AssetImage('assets/images/ghost.png') as ImageProvider,
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)]),
            child: Text(key == 'buyer' ? 'Buyer' : 'Runner',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- Image Proof ---
  Future<void> _pickProofImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (picked != null) {
      setState(() {
        _proofImage = File(picked.path);
      });
    }
  }

  Future<void> _uploadProof() async {
    if (_proofImage == null) return;
    setState(() => _isUploading = true);
    try {
      final url = await _errandService.uploadImage(_proofImage!);
      debugPrint('[ErrandInProgress] proof uploaded -> $url');
      // Optionally call a mutation to attach proof to errand here.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Proof uploaded')));
      setState(() => _proofImage = null);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _checkedStates = List.generate(
        tasks.length, (index) => tasks[index]['completed'] ?? false);
  }

  @override
  void didUpdateWidget(covariant ErrandInProgressScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.errand['tasks'] != widget.errand['tasks']) {
      _checkedStates = List.generate(
          tasks.length, (index) => tasks[index]['completed'] ?? false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reference _distanceMeters to avoid analyzer 'not used' warning (no runtime effect in release)
    assert(() {
      _distanceMeters;
      return true;
    }());

    return Scaffold(
      backgroundColor: AppTheme.neutral100,
      body: Stack(
        children: [
          // 1. Map Background (Consistent with HomeScreen)
          mapbox.MapWidget(
            cameraOptions: mapbox.CameraOptions(
              zoom: 15.0,
              center: _getMapCenter(),
            ),
            onMapCreated: (map) async {
              mapboxMap = map;
              await _addBuyerAndRunnerMarkers();
              await _addPolyline();
              // update overlays after map ready
              await Future.delayed(const Duration(milliseconds: 200));
              await _updateAvatarPositions();
            },
            onCameraChangeListener: (_) async => await _updateAvatarPositions(),
          ),

          // avatar overlays
          _buildAvatarOverlay('buyer', buyerAvatar),
          _buildAvatarOverlay('runner', runnerAvatar),

          // 2. Chat FAB (Floating above the sheet)
          _buildFloatingChat(),

          // 3. Draggable Sheet (Same Skeleton as HomeScreen)
          DraggableScrollableSheet(
            initialChildSize: 0.45,
            minChildSize: 0.35,
            maxChildSize: 0.9,
            snap: true,
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
                    children: [
                      _buildDragHandle(),
                      const SizedBox(height: 20),
                      _buildUserHeader(),
                      const SizedBox(height: 8),
                      // distance / progress message for buyer view
                      if (!widget.isRunner)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white,
                              borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on,
                                  color: AppTheme.primary700),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_formatDistanceMessage(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600))),
                            ],
                          ),
                        ),
                      const SizedBox(height: 18),

                      Text(widget.isRunner
                          ? "Tasks to complete"
                          : "Errand Progress",
                          style: Theme
                              .of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                              color: AppTheme.primary700,
                              fontWeight: FontWeight.bold)),

                      const SizedBox(height: 15),
                      if (widget.isRunner) ..._buildRunnerTasks() else
                        _buildBuyerStatus(),

                      const SizedBox(height: 30),
                      _buildBottomAction(),
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

  Widget _buildUserHeader() {
    final score = widget.isRunner ? buyerTrustScore : runnerTrustScore;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(25)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : const AssetImage('assets/images/ghost.png') as ImageProvider,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userName, style: const TextStyle(
                    color: AppTheme.primary700,
                    fontWeight: FontWeight.w900,
                    fontSize: 18)),
                Text(widget.isRunner ? "Buyer" : "Runner", style: TextStyle(
                    color: AppTheme.primary700.withAlpha((0.6 * 255).toInt()),
                    fontSize: 12)),
                const SizedBox(height: 6),
                _buildRatingSection(score),
              ],
            ),
          ),
          _vDivider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(children: [
              Image.asset('assets/images/cash.png', width: 22),
              const Text("CASH", style: TextStyle(color: AppTheme.primary700,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
            ]),
          ),
          _vDivider(),
          const SizedBox(width: 8),
          Text("XAF \t${totalPrice.toStringAsFixed(0)}", style: const TextStyle(
              color: AppTheme.primary700,
              fontWeight: FontWeight.w900,
              fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildRatingSection(int score) {
    // score in 0..100, convert to 0..5
    final stars = (score / 20).clamp(0, 5).round();
    return Row(
      children: List.generate(5, (i) {
        return Icon(
            i < stars ? Icons.star : Icons.star_border, color: Colors.amber,
            size: 18);
      }),
    );
  }

  Widget _buildTaskItem(String label, String price, bool checked, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(
              color: AppTheme.primary700, fontWeight: FontWeight.w600))),
          Text("XAF $price", style: const TextStyle(
              color: AppTheme.primary700, fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              setState(() {
                _checkedStates[index] = !_checkedStates[index];
              });
            },
            child: Icon(_checkedStates[index] ? Icons.check_circle : Icons
                .radio_button_unchecked, color: AppTheme.primary700),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRunnerTasks() {
    final hasImage = (widget.errand['imageUrl'] ?? '')
        .toString()
        .isNotEmpty;
    return [
      for (int i = 0; i < tasks.length; i++)
        _buildTaskItem(
          tasks[i]['description'] ?? tasks[i].toString(),
          (tasks[i]['price'] ?? 0).toString(),
          _checkedStates[i],
          i,
        ),
      const SizedBox(height: 15),
      Row(
        children: [
          if (hasImage)
            DottedBorder(
              options: RoundedRectDottedBorderOptions(
                radius: const Radius.circular(16),
                dashPattern: const [5, 5],
                strokeWidth: 2,
                color: AppTheme.primary700,
                padding: const EdgeInsets.all(10),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) =>
                        Dialog(
                          child: Image.network(widget.errand['imageUrl']),
                        ),
                  );
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(IconsaxPlusLinear.eye, color: AppTheme.primary700),
                    SizedBox(width: 8),
                    Text(
                      "View image",
                      style: TextStyle(color: AppTheme.primary700),
                    ),
                  ],
                ),
              ),
            ),
          if (hasImage) const SizedBox(width: 30),
          DottedBorder(
            options: RoundedRectDottedBorderOptions(
              radius: const Radius.circular(16),
              dashPattern: const [5, 5],
              strokeWidth: 2,
              color: AppTheme.primary700,
              padding: const EdgeInsets.all(10),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _pickProofImage,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                      IconsaxPlusLinear.export, color: AppTheme.primary700),
                  const SizedBox(width: 8),
                  _isUploading
                      ? const SizedBox(width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text(
                    "Upload proof",
                    style: TextStyle(color: AppTheme.primary700),
                  ),
                ],
              ),
            ),
          ),
          if (_proofImage != null)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                        _proofImage!, width: 48, height: 48, fit: BoxFit.cover),
                  ),
                  IconButton(
                    icon: const Icon(IconsaxPlusLinear.export, color: AppTheme.primary700),
                    onPressed: _isUploading ? null : _uploadProof,
                  ),
                ],
              ),
            ),
        ],
      ),
    ];
  }

  Widget _buildBuyerStatus() {
    return Column(
      children: [
        _buildProgressBar(),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Row(
            children: [
              const Icon(
                  IconsaxPlusLinear.location, color: AppTheme.primary700),
              const SizedBox(width: 12),
              Expanded(child: Text("Runner is currently at the store",
                  style: TextStyle(color: AppTheme.primary700.withAlpha(
                      (0.8 * 255).toInt())))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomAction() {
    return RunAmSlider(
      buttonText: widget.isRunner ? "Complete" : "Cancel Errand",
      circleColor: widget.isRunner ? AppTheme.success : Colors.red,
      borderColor: AppTheme.primary700,
      textStyle: const TextStyle(color: AppTheme.primary700,
          fontSize: 30,
          fontWeight: FontWeight.w900),
      onComplete: () {
        // Use GoRouter and rootNavigatorKey to go to home
        final navContext = rootNavigatorKey.currentContext ?? context;
        GoRouter.of(navContext).go('/home');
      },
    );
  }

  // --- Helper Widgets ---
  Widget _buildDragHandle() =>
      Center(child: Container(width: 40,
          height: 5,
          decoration: BoxDecoration(
              color: AppTheme.primary700.withAlpha((0.2 * 255).toInt()),
              borderRadius: BorderRadius.circular(10))));

  Widget _buildFloatingChat() =>
      Positioned(
        top: MediaQuery
            .of(context)
            .padding
            .top + 20,
        right: 20,
        child: FloatingActionButton.extended(
          onPressed: () {},
          backgroundColor: Colors.white,
          label: const Text("Chat", style: TextStyle(
              color: AppTheme.primary700, fontWeight: FontWeight.w800)),
          icon: const Icon(
              IconsaxPlusLinear.message, color: AppTheme.primary700),
        ),
      );

  Widget _buildProgressBar() {
    return Row(
      children: [
        _stepIcon(Icons.assignment_turned_in, true),
        _stepLine(true),
        _stepIcon(Icons.directions_run, true),
        _stepLine(false),
        _stepIcon(Icons.home, false),
      ],
    );
  }

  Widget _stepIcon(IconData icon, bool active) =>
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: active ? AppTheme.primary700 : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
                color: AppTheme.primary700.withAlpha((0.2 * 255).toInt()))),
        child: Icon(icon,
            color: active ? Colors.white : AppTheme.primary700.withAlpha(
                (0.3 * 255).toInt()), size: 20),
      );

  Widget _stepLine(bool active) =>
      Expanded(child: Container(height: 2,
          color: active ? AppTheme.primary700 : AppTheme.primary700.withAlpha(
              (0.2 * 255).toInt())));

  Widget _vDivider() =>
      Container(height: 30,
          width: 1.5,
          color: AppTheme.primary700.withAlpha((0.2 * 255).toInt()));

  // --- Mapbox Helpers ---
  mapbox.Point _getMapCenter() {
    final lat = (buyerLoc != null
        ? (buyerLoc!['latitude'] ?? buyerLoc!['lat'])
        : runnerLoc != null
        ? (runnerLoc!['latitude'] ?? runnerLoc!['lat'])
        : null)?.toDouble();
    final lng = (buyerLoc != null
        ? (buyerLoc!['longitude'] ?? buyerLoc!['lng'])
        : runnerLoc != null
        ? (runnerLoc!['longitude'] ?? runnerLoc!['lng'])
        : null)?.toDouble();
    return mapbox.Point(coordinates: mapbox.Position(lng ?? 0, lat ?? 0));
  }

  Future<void> _addBuyerAndRunnerMarkers() async {
    if (mapboxMap == null) return;
    final buyerLat = buyerLoc != null ? (buyerLoc!['latitude'] ??
        buyerLoc!['lat'])?.toDouble() : null;
    final buyerLng = buyerLoc != null ? (buyerLoc!['longitude'] ??
        buyerLoc!['lng'])?.toDouble() : null;
    final runnerLat = runnerLoc != null ? (runnerLoc!['latitude'] ??
        runnerLoc!['lat'])?.toDouble() : null;
    final runnerLng = runnerLoc != null ? (runnerLoc!['longitude'] ??
        runnerLoc!['lng'])?.toDouble() : null;

    final List<Map<String, dynamic>> features = [];
    if (buyerLat != null && buyerLng != null) {
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [buyerLng, buyerLat],
        },
        'properties': {
          'icon': 'marker-15',
        },
      });
    }
    if (runnerLat != null && runnerLng != null) {
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [runnerLng, runnerLat],
        },
        'properties': {
          'icon': 'marker-15',
        },
      });
    }
    try {
      await mapboxMap!.style.removeStyleLayer('marker-layer');
    } catch (_) {}
    try {
      await mapboxMap!.style.removeStyleSource('marker-source');
    } catch (_) {}
    if (features.isNotEmpty) {
      await mapboxMap!.style.addSource(
        mapbox.GeoJsonSource(
          id: 'marker-source',
          data: jsonEncode({"type": "FeatureCollection", "features": features}),
        ),
      );
      await mapboxMap!.style.addLayer(
        mapbox.SymbolLayer(
          id: 'marker-layer',
          sourceId: 'marker-source',
          iconImage: 'marker-15',
          iconSize: 1.5,
        ),
      );
    }
  }

  Future<void> _addPolyline() async {
    if (mapboxMap == null || buyerLoc == null || runnerLoc == null) return;
    final buyerLat = (buyerLoc!['latitude'] ?? buyerLoc!['lat'])?.toDouble();
    final buyerLng = (buyerLoc!['longitude'] ?? buyerLoc!['lng'])?.toDouble();
    final runnerLat = (runnerLoc!['latitude'] ?? runnerLoc!['lat'])?.toDouble();
    final runnerLng = (runnerLoc!['longitude'] ?? runnerLoc!['lng'])
        ?.toDouble();
    if ([buyerLat, buyerLng, runnerLat, runnerLng].any((v) => v == null))
      return;
    try {
      await mapboxMap!.style.removeStyleLayer('polyline-layer');
    } catch (_) {}
    try {
      await mapboxMap!.style.removeStyleSource('polyline-source');
    } catch (_) {}
    final polylineGeoJson = '{"type": "FeatureCollection", "features": [{"type": "Feature", "geometry": {"type": "LineString", "coordinates": [[${buyerLng}, ${buyerLat}], [${runnerLng}, ${runnerLat}]]}}]}';
    await mapboxMap!.style.addSource(
      mapbox.GeoJsonSource(
        id: 'polyline-source',
        data: jsonEncode(jsonDecode(polylineGeoJson)),
      ),
    );
    await mapboxMap!.style.addLayer(
      mapbox.LineLayer(
        id: 'polyline-layer',
        sourceId: 'polyline-source',
        lineColor: AppTheme.primary700.toARGB32(),
        lineWidth: 5.0,
      ),
    );
  }
}
