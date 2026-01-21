import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../services/runner_polling_service.dart';
import '../graphql/errand_queries.dart';
import '../services/graphql_client.dart';
import 'auth_controller.dart';

class RunnerOfferController extends GetxController {
  static const _tag = '🏷️ [RunnerOfferController]';

  late RunnerPollingService _poller;
  StreamSubscription? _pollerSub;
  final StreamController<List<Map<String, dynamic>>> _offersController = StreamController.broadcast();
  Stream<List<Map<String, dynamic>>> get offers => _offersController.stream;
  // Reactive latest offers for router-level redirect logic
  final RxList<Map<String, dynamic>> latestOffers = <Map<String, dynamic>>[].obs;
  bool get hasOffers => latestOffers.isNotEmpty;

  // Track last navigated offer ids to avoid repeated navigation for the same batch
  Set<String> _lastNavigatedIds = {};

  bool _isActive = false;

  @override
  void onInit() {
    super.onInit();
    debugPrint('$_tag Initializing controller...');

    // Don't start polling until the user is authenticated so the client has JWT
    try {
      final auth = Get.find<AuthController>();

      // If already authenticated, start immediately with current client
      if (auth.isAuthenticated.value) {
        _startWithCurrentClient();
      }

      // React to authentication becoming true: start/recreate poller
      ever<bool>(auth.isAuthenticated, (isAuth) {
        if (isAuth == true) {
          debugPrint('$_tag Authenticated -> starting/restarting poller');
          _startWithCurrentClient();
        }
      });

      // Also react to accessToken changes to recreate the poller if necessary
      ever<String?>(auth.accessToken, (token) {
        if (token != null && token.isNotEmpty) {
          debugPrint('$_tag Access token changed -> recreating poller with new client');
          _startWithCurrentClient();
        }
      });
    } catch (e) {
      // If AuthController is not available yet, start with current client as fallback
      debugPrint('$_tag AuthController not found during init: $e. Starting poller with current client');
      _startWithCurrentClient();
    }
  }

  void _startWithCurrentClient() {
    // Dispose previous poller subscription if present
    try {
      _pollerSub?.cancel();
    } catch (_) {}

    try {
      _poller = RunnerPollingService(client: GraphQLClientInstance.client);
      // Start underlying poller; it will call the GraphQL query periodically
      _poller.startPolling(query: runnerPendingOffersQuery, interval: const Duration(seconds: 5));

      // Listen and forward results to our stream; keep subscription to cancel on recreate
      _pollerSub = _poller.events.listen((offers) {
        try {
          final list = offers.map((e) => Map<String, dynamic>.from(e)).toList();
          debugPrint('$_tag Received ${list.length} offers');
          // log ids for visibility
          try {
            final ids = list.map((e) => e['id']?.toString() ?? '<no-id>').toList();
            debugPrint('$_tag Offer ids: $ids');
          } catch (_) {}
          // If there are no offers, clear last navigated ids so future offers can trigger navigation
          if (list.isEmpty) {
            if (_lastNavigatedIds.isNotEmpty) {
              debugPrint('$_tag No offers returned — clearing navigation history');
              _lastNavigatedIds.clear();
            }
          }
          // update reactive latestOffers for router redirect
          try {
            latestOffers.assignAll(list);
            // notify router to re-evaluate redirects
            try { offersRefresh.value = offersRefresh.value + 1; } catch (_) {}
          } catch (_) {}
          if (!_offersController.isClosed) _offersController.add(list);
        } catch (e) {
          debugPrint('$_tag Failed to forward offers: $e');
        }
      });

      _isActive = true;
    } catch (e) {
      debugPrint('$_tag Failed to start poller with current client: $e');
    }
  }

  void _start() {
    // kept for compatibility but prefer _startWithCurrentClient
    _startWithCurrentClient();
  }

  Future<void> stopPolling() async {
    debugPrint('$_tag stopPolling called');
    _isActive = false;
    try {
      await _poller.stopPolling();
    } catch (e) {
      debugPrint('$_tag stopPolling error: $e');
    }
  }

  Future<void> disposeController() async {
    debugPrint('$_tag Disposing controller');
    try {
      await _poller.dispose();
    } catch (_) {}
    try {
      await _pollerSub?.cancel();
    } catch (_) {}
    await _offersController.close();
  }

  // Navigation guard helper: returns true if we should navigate for this batch
  bool shouldNavigateForBatch(List<Map<String, dynamic>> batch) {
    final ids = batch.map((e) => e['id']?.toString() ?? '').where((s) => s.isNotEmpty).toSet();
    if (ids.isEmpty) return false;
    // if different from last navigated ids, indicate navigation should occur
    final should = ids.difference(_lastNavigatedIds).isNotEmpty;
    return should;
  }

  /// Record that we've navigated for this batch of ids — call after successful navigation
  void recordNavigatedIds(List<Map<String, dynamic>> batch) {
    final ids = batch.map((e) => e['id']?.toString() ?? '').where((s) => s.isNotEmpty).toSet();
    if (ids.isEmpty) return;
    _lastNavigatedIds = ids;
    debugPrint('$_tag recordNavigatedIds saved: $_lastNavigatedIds');
  }

  /// Clears the navigation history (last navigated ids), used when navigation failed
  void resetNavigationHistory() {
    debugPrint('$_tag resetNavigationHistory called — clearing _lastNavigatedIds');
    _lastNavigatedIds.clear();
  }
}

// Global notifier used by GoRouter to refresh redirects when offers change
final ValueNotifier<int> offersRefresh = ValueNotifier<int>(0);

