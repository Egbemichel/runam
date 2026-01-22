import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../features/errand/models/errand.dart';
import '../features/errand/screens/errand_in_progress.dart';
import '../graphql/errand_queries.dart';
import '../services/graphql_client.dart';
import 'auth_controller.dart';

class BuyerErrandStatusController extends GetxController {
  static const _tag = '🕵️ [BuyerErrandStatusController]';

  Timer? _timer;
  final RxnString trackingErrandId = RxnString();
  final RxBool isChecking = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Automatically stop tracking if user logs out
    ever(Get.find<AuthController>().isAuthenticated, (bool auth) {
      if (!auth) stopTracking();
    });
  }

  /// Start global polling for a specific errand
  void startTracking(String errandId) {
    debugPrint('$_tag Starting global tracking for Errand: $errandId');
    trackingErrandId.value = errandId;
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _checkStatus());
    _checkStatus(); // Initial check
  }

  void stopTracking() {
    debugPrint('$_tag Stopping tracking');
    _timer?.cancel();
    trackingErrandId.value = null;
  }

  Future<void> _checkStatus() async {
    if (trackingErrandId.value == null || isChecking.value) return;

    isChecking.value = true;
    try {
      final client = GraphQLClientInstance.client;
      final result = await client.query(QueryOptions(
        document: gql(errandStatusQuery), // Ensure this query returns status and runner info
        variables: {'id': trackingErrandId.value},
        fetchPolicy: FetchPolicy.networkOnly,
      ));

      if (result.hasException) {
        debugPrint('$_tag Poll error: ${result.exception}');
        return;
      }

      final data = result.data?['errand'];
      if (data == null) return;

      final String status = data['status'] ?? '';

      // TRIGGER: If runner accepted, navigate the Buyer
      if (status == 'ACCEPTED' || status == 'IN_PROGRESS') {
        debugPrint('$_tag Errand Accepted! Navigating Buyer...');
        stopTracking();
        _navigateToInProgress(data);
      } else if (status == 'CANCELLED' || status == 'EXPIRED') {
        stopTracking();
        Get.snackbar("Errand Update", "Your errand was $status",
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      debugPrint('$_tag Exception: $e');
    } finally {
      isChecking.value = false;
    }
  }

  void _navigateToInProgress(Map<String, dynamic> errandData) {
    // Ensure we aren't already on the progress screen
    if (Get.currentRoute.contains('errand-in-progress')) return;

    Get.offAll(() => ErrandInProgressScreen(errand: errandData));
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}