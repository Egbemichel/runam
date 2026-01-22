// File: lib/screens/runner/runner_request_accept.dart

import 'dart:async';
import 'dart:ui';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:get/get.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import '../../features/errand/screens/errand_in_progress.dart';
import '../home/home_screen.dart';
import '../../controllers/location_controller.dart';
import '../../components/runam_slider.dart';
import '../../controllers/runner_offer_controller.dart';
import '../../../app/theme.dart';
import '../../../graphql/errand_queries.dart';

class RunnerDashboard extends StatefulWidget {
  const RunnerDashboard({super.key});

  static const String routeName = 'runner-dashboard';
  static const String path = '/runner-dashboard';

  @override
  State<RunnerDashboard> createState() => _RunnerDashboardState();
}

class _RunnerDashboardState extends State<RunnerDashboard> {
  List<Map<String, dynamic>> _pendingOffers = [];
  bool _isAccepting = false;
  bool _pollingStarted = false;
  StreamSubscription? _offersSub;
  mapbox.CameraOptions? _cameraOptions;
  mapbox.MapboxMap? mapboxMap;
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  bool _isFollowingUser = true;
  late final LocationController _locationController;

  @override
  void initState() {
    super.initState();
    try {
      _locationController = Get.find<LocationController>();
      final payload = _locationController.toPayload();
      if (payload.isNotEmpty) {
        final lat = (payload['latitude'] as num).toDouble();
        final lng = (payload['longitude'] as num).toDouble();
        _cameraOptions = mapbox.CameraOptions(
          center: mapbox.Point(coordinates: mapbox.Position(lng, lat)),
          zoom: 15.0,
        );
      }
      ever(_locationController.locationMode, (_) => _onLocationPayloadChanged());
      ever(_locationController.currentPosition, (_) => _onLocationPayloadChanged());
      ever(_locationController.staticPlace, (_) => _onLocationPayloadChanged());
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_pollingStarted) {
      final controller = Get.find<RunnerOfferController>();
      _offersSub = controller.offers.listen((offers) {
        final now = DateTime.now().toUtc();
        final filtered = offers.where((offer) {
          try {
            if (offer['expiresAt'] != null) {
              final dt = DateTime.parse(offer['expiresAt'].toString()).toUtc();
              if (dt.isBefore(now)) return false;
            }
          } catch (e) {
            debugPrint(e.toString());
          }
          return true;
        }).toList();

        if (mounted) setState(() => _pendingOffers = filtered);
      });
      _pollingStarted = true;
    }
  }

  @override
  void dispose() {
    _offersSub?.cancel();
    _sheetController.dispose();
    super.dispose();
  }

  // --- Logic Helpers ---
  String safeString(dynamic v, [String fallback = '']) => v?.toString() ?? fallback;
  double safeDouble(dynamic v, [double fallback = 0.0]) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  Color _withOpacity(Color c, double opacity) {
    final alpha = (opacity * 255).clamp(0, 255).round();
    return c.withAlpha(alpha);
  }

  double _computeTotalPrice(Map<String, dynamic>? offer, List<dynamic> tasks) {
    final p = offer != null ? offer['price'] : null;
    final offerPrice = safeDouble(p, double.nan);
    if (!offerPrice.isNaN && offerPrice > 0) return offerPrice;

    double sum = 0;
    for (final t in tasks) {
      sum += safeDouble(t is Map ? t['price'] : t);
    }
    return sum;
  }

  String _computeExpiresIn(Map<String, dynamic>? offer) {
    try {
      final expiresAt = offer?['expiresAt'] ?? offer?['expires_at'] ?? offer?['expiresIn'];
      if (expiresAt == null) return safeString(offer?['expiresIn'] ?? 'Soon');
      if (expiresAt is String && !expiresAt.contains(RegExp(r'\d{4}-\d{2}-\d{2}'))) {
        return expiresAt;
      }
      final dt = DateTime.parse(expiresAt.toString()).toUtc();
      final diff = dt.difference(DateTime.now().toUtc());
      if (diff.inMinutes <= 0) return 'Now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}mins';
      if (diff.inHours < 24) return '${diff.inHours}h ${diff.inMinutes % 60}m';
      return '${diff.inDays}d';
    } catch (_) {
      return safeString(offer?['expiresIn'] ?? 'Soon');
    }
  }

  Future<void> _acceptOffer(String offerId) async {
    if (_isAccepting) return;
    setState(() => _isAccepting = true);

    try {
      final client = GraphQLProvider.of(context).value;
      final QueryResult result = await client.mutate(MutationOptions(
        document: gql(acceptOfferMutation),
        variables: {'offerId': offerId},
        fetchPolicy: FetchPolicy.networkOnly,
      ));

      if (result.hasException) {
        final errors = result.exception?.graphqlErrors ?? [];
        final message = errors.isNotEmpty ? errors.first.message : "Connection error";
        if (message.toLowerCase().contains('expired')) {
          _handleExit(message, isWarning: true);
          return;
        }
        throw Exception(message);
      }

      final data = result.data?['acceptErrandOffer'];
      final bool ok = data?['ok'] == true;

      if (ok) {
        Get.find<RunnerOfferController>().stopPolling();
        _offersSub?.cancel();

        final Map<String, dynamic> officialErrand = data['errand'] ?? {};

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Offer accepted!'), backgroundColor: Colors.green)
          );

          // Use Get.off to avoid Navigator 2.0 imperative API conflicts
          Future.delayed(const Duration(milliseconds: 100), () {
            Get.off(() => ErrandInProgressScreen(errand: officialErrand));
          });
        }
      } else {
        throw Exception('This offer is no longer available.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceAll('Exception:', '')), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  void _handleExit(String message, {bool isWarning = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: isWarning ? Colors.orange : Colors.red)
    );
    Get.offAll(() => const HomeScreen());
  }

  Future<void> _declineOffer(String offerId) async {
    try {
      final client = GraphQLProvider.of(context).value;
      final QueryResult result = await client.mutate(MutationOptions(
        document: gql(rejectOfferMutation),
        variables: {'offerId': offerId},
        fetchPolicy: FetchPolicy.networkOnly,
      ));

      if (result.hasException) {
        final msg = result.exception?.graphqlErrors.map((e) => e.message).join(', ') ?? result.exception.toString();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $msg'), backgroundColor: Colors.red));
        }
        return;
      }

      final dynamic data = result.data?['rejectErrandOffer'];
      final bool ok = data?['ok'] == true || data?['ok'] == 1;

      if (ok) {
        if (mounted) {
          setState(() {
            _pendingOffers.removeWhere((o) => o['id'].toString() == offerId.toString());
          });
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Offer declined'), backgroundColor: Colors.orange)
          );
          Get.offAll(() => const HomeScreen());
        }
      }
    } catch (e) {
      debugPrint("Decline Error: $e");
    }
  }

  Future<void> _onLocationPayloadChanged() async {
    if (!mounted) return;
    final payload = _locationController.toPayload();
    if (payload.isEmpty) return;
    if (_isFollowingUser) setState(() => _isFollowingUser = false);
  }

  @override
  Widget build(BuildContext context) {
    final currentOffer = _pendingOffers.isNotEmpty ? _pendingOffers.first : null;

    return Scaffold(
      backgroundColor: AppTheme.secondary500,
      body: Stack(
        children: [
          mapbox.MapWidget(
            cameraOptions: _cameraOptions,
            onMapCreated: (map) => mapboxMap = map,
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.65,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            controller: _sheetController,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: AppTheme.secondary500,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(25, 30, 25, 40),
                  child: currentOffer != null ? _buildRequestPanel(currentOffer) : _buildEmptyState(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRequestPanel(Map<String, dynamic> offer) {
    final Map<String, dynamic>? errand = (offer['errand'] is Map)
        ? Map<String, dynamic>.from(offer['errand'] as Map)
        : null;
    final List<dynamic> tasks = (errand != null && errand['tasks'] is List) ? List<dynamic>.from(errand['tasks'] as List) : [];
    final double totalPrice = _computeTotalPrice(offer, tasks);

    final String userName = safeString(errand?['userName'] ?? 'Client');
    final int trustScore = (errand?['userTrustScore'] != null) ? safeDouble(errand!['userTrustScore']).round() : 0;

    final String rawUrl = safeString(errand?['imageUrl'] ?? errand?['image_url'] ?? '');
    final String imageUrl = rawUrl.isNotEmpty ? rawUrl : 'https://ui-avatars.com/api/?name=$userName&background=8B6BFF&color=fff';

    final String userRating = '$trustScore/100';
    final String expiresIn = _computeExpiresIn(offer);
    final String paymentMethod = safeString(offer['paymentMethod'] ?? errand?['paymentMethod'] ?? 'cash');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.primary700.withAlpha(30),
                child: ClipOval(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: 56,
                    height: 56,
                    errorBuilder: (context, error, stackTrace) => Icon(Icons.person, color: AppTheme.primary700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userName, style: TextStyle(color: AppTheme.primary700, fontWeight: FontWeight.w900, fontSize: 18)),
                    Row(children: [
                      Image.asset('assets/images/shield-tick.png', width: 14, errorBuilder: (c,e,s) => const Icon(Icons.verified, size: 14)),
                      const SizedBox(width: 4),
                      Text(userRating, style: TextStyle(color: _withOpacity(AppTheme.primary700, 0.7), fontSize: 13, fontWeight: FontWeight.bold)),
                    ]),
                  ],
                ),
              ),
              _vDivider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(children: [
                  Image.asset('assets/images/cash.png', width: 24, errorBuilder: (c,e,s) => const Icon(Icons.payments)),
                  Text(paymentMethod.toUpperCase(), style: TextStyle(color: AppTheme.primary700, fontSize: 11, fontWeight: FontWeight.bold)),
                ]),
              ),
              _vDivider(),
              const SizedBox(width: 8),
              Text("XAF ${totalPrice.toInt()}", style: TextStyle(color: AppTheme.primary700, fontWeight: FontWeight.w900, fontSize: 18)),
            ],
          ),
        ),
        const SizedBox(height: 25),
        ...tasks.map((t) => _buildTaskItem(safeString(t is Map ? t['description'] : t), safeString(t is Map ? t['price'] : '0'))),
        const SizedBox(height: 10),
        // Text("In $expiresIn", style: TextStyle(color: AppTheme.primary700, fontWeight: FontWeight.w900, fontSize: 17)),
        const SizedBox(height: 25),
        Row(
          children: [
            Expanded(
              flex: 4,
              child: DottedBorder(
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
                    // Handle image preview
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(IconsaxPlusLinear.eye, color: AppTheme.primary700),
                      const SizedBox(width: 8),
                      Text(
                        "View image",
                        style: TextStyle(color: AppTheme.primary700),
                      ),
                    ],
                  ),
                ),
              ),

            ),
            const SizedBox(width: 15),
            Expanded(
              flex: 5,
              child: GestureDetector(
                onTap: () => _declineOffer(offer['id']),
                child: Container(
                  height: 55,
                  decoration: BoxDecoration(border: Border.all(color: Colors.red, width: 2), borderRadius: BorderRadius.circular(15)),
                  child: const Center(child: Text("Decline", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 24, fontStyle: FontStyle.italic))),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 25),
        RunAmSlider(
          buttonText: "Confirm",
          circleColor: AppTheme.primary700,
          borderColor: AppTheme.primary700,
          textStyle: TextStyle(color: AppTheme.secondary500, fontSize: 28, fontWeight: FontWeight.w900),
          onComplete: () => _acceptOffer(offer['id']),
        ),
      ],
    );
  }

  Widget _buildTaskItem(String label, String price) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: _withOpacity(AppTheme.primary700, 0.1))),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: AppTheme.primary700, fontSize: 15, fontWeight: FontWeight.w500))),
          Text("XAF", style: TextStyle(color: AppTheme.primary700, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(width: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(border: Border.all(color: _withOpacity(AppTheme.primary700, 0.5)), borderRadius: BorderRadius.circular(12)),
            child: Text(price, style: TextStyle(color: AppTheme.primary700, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 15),
          Container(width: 32, height: 32, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.primary700, width: 2))),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(height: 35, width: 1.5, color: _withOpacity(AppTheme.primary700, 0.5));
  Widget _buildEmptyState() => const Center(child: CircularProgressIndicator());
}