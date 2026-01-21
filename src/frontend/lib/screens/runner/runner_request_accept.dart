// File: lib/features/runner/screens/runner_dashboard.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:get/get.dart';
import 'package:runam/features/errand/screens/errand_searching.dart'; // Ensure this import exists or remove if unused
import '../../components/runam_slider.dart';
import '../../controllers/runner_offer_controller.dart';
import '../../../app/theme.dart';
import '../../../graphql/errand_queries.dart';

// Helper for dashed border
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  DashedBorderPainter({this.color = Colors.black, this.strokeWidth = 1.0, this.gap = 5.0});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final Path path = Path();
    path.addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(15)));

    Path dashPath = Path();
    double dashWidth = 10.0;
    double distance = 0.0;

    for (PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + gap;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
  String? _navigatedOfferId;
  StreamSubscription? _offersSub;

  // Colors extracted from the design image
  final Color _bgCyan = const Color(0xFFA0F1FF); // Light blue/cyan bg
  final Color _purpleMain = const Color(0xFF8B7EF8); // Purple button/accents
  final Color _darkText = const Color(0xFF1A1A40); // Dark text
  final Color _cardBorder = const Color(0xFF6A5ACD); // Task border

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_pollingStarted) {
      final controller = Get.find<RunnerOfferController>();
      debugPrint('[RunnerDashboard] Subscribing to session-level offers stream...');
      _offersSub = controller.offers.listen((offers) {
        final now = DateTime.now().toUtc();
        final filtered = offers.where((offer) {
          try {
            if (offer['expiresAt'] != null) {
              final String ts = offer['expiresAt'].toString();
              final dt = DateTime.parse(ts).toUtc();
              if (dt.isBefore(now)) return false;
            }
            if (offer['expiresIn'] != null) {
              final num v = offer['expiresIn'] is num
                  ? offer['expiresIn'] as num
                  : num.parse(offer['expiresIn'].toString());
              if (v <= 0) return false;
            }
          } catch (e) {
            debugPrint('[RunnerDashboard] Expiry parse error: $e');
          }
          return true;
        }).toList();

        if (mounted) {
          setState(() {
            _pendingOffers = filtered;
          });
        }
      });
      _pollingStarted = true;
    }
  }

  @override
  void dispose() {
    _offersSub?.cancel();
    super.dispose();
  }

  Future<void> _acceptOffer(String offerId) async {
    if (_isAccepting) return;
    setState(() => _isAccepting = true);

    try {
      final client = GraphQLProvider.of(context).value;
      final MutationOptions options = MutationOptions(
        document: gql(acceptOfferMutation),
        variables: {'offerId': offerId},
      );

      final QueryResult result = await client.mutate(options);

      if (result.hasException) throw Exception(result.exception.toString());
      final dynamic successRaw = result.data?['acceptErrandOffer']?['ok'];
      final bool success = (successRaw is bool)
          ? successRaw
          : (successRaw is num)
              ? successRaw != 0
              : (successRaw?.toString().toLowerCase() == 'true' || successRaw?.toString() == '1');

      if (success == true) {
        final sessionController = Get.find<RunnerOfferController>();
        await sessionController.stopPolling();
        await _offersSub?.cancel();

        final accepted = _pendingOffers.firstWhere(
                (o) => o['id'].toString() == offerId.toString(),
            orElse: () => {});
        final errandPayload = (accepted is Map && accepted.containsKey('errand'))
            ? accepted['errand'] as Map<String, dynamic>
            : {'status': 'IN_PROGRESS'};

        if (mounted) {
          setState(() {
            _pendingOffers.removeWhere((o) => o['id'].toString() == offerId.toString());
            _navigatedOfferId = offerId;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Offer accepted!'), backgroundColor: Colors.green),
          );

          if (_navigatedOfferId == null) {
            _navigatedOfferId = offerId;
            // Assuming ErrandInProgressScreen exists in your project
            // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ErrandInProgressScreen(errand: errandPayload)));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  Future<void> _declineOffer(String offerId) async {
    debugPrint('[RunnerDashboard] Declining offer $offerId -> calling reject mutation');

    try {
      final client = GraphQLProvider.of(context).value;

      final MutationOptions options = MutationOptions(
        document: gql(rejectOfferMutation),
        variables: {'offerId': offerId},
      );

      final QueryResult result = await client.mutate(options);

      if (result.hasException) {
        throw Exception(result.exception.toString());
      }

      final dynamic successRejectRaw = result.data?['rejectErrandOffer']?['ok'];
      final bool successReject = (successRejectRaw is bool)
          ? successRejectRaw
          : (successRejectRaw is num)
              ? successRejectRaw != 0
              : (successRejectRaw?.toString().toLowerCase() == 'true' || successRejectRaw?.toString() == '1');

      if (successReject == true) {
        debugPrint('[RunnerDashboard] Offer $offerId successfully rejected on server');
        if (mounted) {
          setState(() {
            _pendingOffers.removeWhere((o) => o['id'].toString() == offerId.toString());
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Offer declined'), backgroundColor: Colors.orange),
          );
        }
      } else {
        debugPrint('[RunnerDashboard] Server responded with ok=false for reject');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not decline offer'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint('[RunnerDashboard] Decline error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If we have offers, show the first one. Otherwise show waiting state.
    final currentOffer = _pendingOffers.isNotEmpty ? _pendingOffers.first : null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Map Background Layer
          Positioned.fill(
            child: _buildMapBackground(),
          ),

          // 2. Top Navigation (Back Button)
          Positioned(
            top: 50,
            left: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),

          // 3. The Errand Request Sheet (Cyan Card)
          if (currentOffer != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildRequestPanel(currentOffer),
            )
          else
            _buildEmptyState(),
        ],
      ),
    );
  }

  // Placeholder for the Map. Replace this with your GoogleMap widget.
  Widget _buildMapBackground() {
    return Container(
      color: const Color(0xFFF0F4F8), // Map-like grey
      child: Stack(
        children: [
          // Draw some dummy roads/map elements just for visual context in this preview
          Positioned(
              top: 100,
              right: 50,
              child: Icon(Icons.location_on, color: _purpleMain, size: 40)),
          Positioned(
            top: 250,
            left: 100,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green, width: 2)),
              child: const CircleAvatar(
                radius: 15,
                backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11'), // Dummy avatar
              ),
            ),
          ),
          Center(
              child: Text("Map View Area",
                  style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 24,
                      fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text('Searching for errands...',
                style: TextStyle(
                    color: _darkText, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestPanel(Map<String, dynamic> offer) {
    final errand = offer['errand'] as Map<String, dynamic>?;
    final tasks = errand?['tasks'] as List<dynamic>? ?? [];
    final totalPrice = offer['price'] ?? 0;

    // Extract user info
    final requester = errand?['requester'] ?? {};
    final userName = requester['name'] ?? 'Client';
    final userRating = '71/100'; // Hardcoded based on image, or fetch from API

    // Calculate time (dummy or real)
    final expiresIn = offer['expiresIn'] ?? '24mins';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _bgCyan,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Header: User Profile & Price ---
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 22,
                  backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=8'), // Placeholder
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "$userName | M",
                            style: TextStyle(
                              color: _darkText,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.shield, color: Colors.green, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            userRating,
                            style: TextStyle(color: _darkText.withOpacity(0.7), fontSize: 12),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                // Divider
                Container(height: 30, width: 2, color: _darkText),
                const SizedBox(width: 10),
                // Cash
                Column(
                  children: [
                    const Icon(Icons.money, color: Colors.green, size: 20),
                    Text("cash", style: TextStyle(fontSize: 10, color: _darkText)),
                  ],
                ),
                const SizedBox(width: 10),
                Container(height: 30, width: 2, color: _darkText),
                const SizedBox(width: 10),
                // Price
                Text(
                  "XAF $totalPrice",
                  style: TextStyle(
                    color: _darkText,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // --- Tasks List ---
          if (tasks.isNotEmpty) ...tasks.map((task) => _buildTaskPill(task)),

          // --- Time Estimate ---
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "In $expiresIn", // e.g. "In 24mins"
              style: TextStyle(
                color: _darkText,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // --- Buttons Row 1: View Image & Decline ---
          Row(
            children: [
              // View Image Button
              Expanded(
                flex: 4,
                child: CustomPaint(
                  painter: DashedBorderPainter(color: _darkText, strokeWidth: 1),
                  child: TextButton.icon(
                    onPressed: () {
                      // Handle view image
                    },
                    icon: Icon(Icons.image_outlined, color: _darkText),
                    label: Text("View image", style: TextStyle(color: _darkText)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Decline Button
              Expanded(
                flex: 5,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red, width: 1.5),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: TextButton(
                    onPressed: _isAccepting ? null : () => _declineOffer(offer['id']),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      "Decline",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        fontFamily: 'Cursive', // Tries to mimic the playful font
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // --- Accept Button (Slider Look) ---
          RunAmSlider(
            buttonText: "Request",
            circleColor: AppTheme.success,
            borderColor: AppTheme.success,
            textStyle: TextStyle(
              color: AppTheme.success
            ),
            enabled: true,
            // Provide a synchronous callback; start async work without returning Future
            onComplete: () {
              _isAccepting ? null : () => _acceptOffer(offer['id']);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTaskPill(dynamic task) {
    final desc = task['description'] ?? 'Task';
    final price = task['price'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Task Name
          Expanded(
            child: Text(
              desc,
              style: TextStyle(
                color: _cardBorder,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          // Price
          Row(
            children: [
              Text(
                "XAF ",
                style: TextStyle(
                  color: _darkText,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                "$price",
                style: TextStyle(
                  color: _darkText,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Checkbox/Square (Visual only)
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.transparent, // or _purpleMain for checked
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _cardBorder, width: 1.5),
            ),
            // child: Icon(Icons.check, size: 16, color: Colors.white), // Uncomment for checked state
          )
        ],
      ),
    );
  }
}
