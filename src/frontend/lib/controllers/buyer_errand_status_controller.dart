import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:go_router/go_router.dart';
import '../graphql/errand_queries.dart';
import '../services/graphql_client.dart';
import '../app/router.dart'; // rootNavigatorKey is defined here

/// Behavioral Pattern: Mediator
/// This controller mediates between the UI, backend polling, and navigation logic for buyer errand status.
/// It encapsulates the polling logic and navigation, so the UI does not need to know about backend or routing details.
class BuyerErrandStatusController extends GetxController {
  static const _tag = '🕵️ [BuyerStatus]';

  Timer? _timer;
  // Observer Pattern: Rx variables allow UI to reactively update when these change
  final RxnString trackingErrandId = RxnString();
  final RxBool isChecking = false.obs;

  /// Command Pattern: Encapsulates the action of starting polling for an errand
  void startTracking(String errandId) {
    debugPrint('$_tag [STEP 1] Start Tracking for: $errandId');
    trackingErrandId.value = errandId;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _checkStatus());
    _checkStatus();
  }

  /// Command Pattern: Encapsulates the action of stopping polling
  void stopTracking() {
    debugPrint('$_tag [STOP] Polling terminated.');
    _timer?.cancel();
    _timer = null;
    trackingErrandId.value = null;
  }

  /// Template Method Pattern: _checkStatus defines the skeleton of polling logic, with overridable steps for error/status handling
  Future<void> _checkStatus() async {
    if (trackingErrandId.value == null) return;
    if (isChecking.value) {
      debugPrint('$_tag [SKIP] Already checking status...');
      return;
    }

    isChecking.value = true;
    try {
      debugPrint('$_tag [STEP 2] Requesting status from Backend for ID: ${trackingErrandId.value}');
      final client = GraphQLClientInstance.client;
      final result = await client.query(QueryOptions(
        document: gql(errandStatusQuery),
        variables: {'id': trackingErrandId.value},
        fetchPolicy: FetchPolicy.networkOnly,
      ));

      if (result.hasException) {
        debugPrint('$_tag [ERROR] GQL Error: ${result.exception}');
        return;
      }

      final data = result.data?['errand'];
      if (data == null) {
        debugPrint('$_tag [WARN] Errand data is NULL');
        return;
      }

      final String status = data['status'] ?? '';
      debugPrint('$_tag [STEP 3] Current Backend Status: "$status"');

      // Strategy Pattern: Different strategies for handling status
      if (status == 'ACCEPTED' || status == 'IN_PROGRESS') {
        debugPrint('$_tag [STEP 4] STATUS MATCHED! Stopping poll and moving...');
        stopTracking();
        _navigateToInProgress(data);
      } else if (status == 'CANCELLED' || status == 'EXPIRED') {
        debugPrint('$_tag [EXIT] Errand was $status');
        stopTracking();
        Get.snackbar("Errand Update", "Your errand was $status");
      }
    } catch (e) {
      debugPrint('$_tag [CRITICAL] Exception in loop: $e');
    } finally {
      isChecking.value = false;
    }
  }

  /// Command Pattern: Encapsulates the navigation action
  void _navigateToInProgress(Map<String, dynamic> errandData) {
    debugPrint('$_tag [STEP 5] Attempting Navigation...');

    // 1. Get the Context via the Global Key
    final context = rootNavigatorKey.currentContext;

    if (context == null) {
      debugPrint('$_tag [FAILURE] rootNavigatorKey.currentContext is NULL. Navigation cannot proceed.');
      return;
    }

    debugPrint('$_tag [SUCCESS] Context found. Executing context.go()');

    // 2. Execute GoRouter navigation
    // We wrap in a callback to ensure we aren't in the middle of a build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.go(
        '/errand-in-progress',
        extra: {
          ...errandData,
          'isRunner': false, // Crucial for Buyer UI
        },
      );
    });
  }
}