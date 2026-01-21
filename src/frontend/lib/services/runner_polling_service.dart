// lib/services/runner_polling_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

class RunnerPollingService {
  final GraphQLClient client;
  Timer? _pollingTimer;

  // Use a map to track the IDs we've already seen to prevent duplicate alerts
  final Set<String> _notifiedOfferIds = {};

  final StreamController<List<Map<String, dynamic>>> _eventController =
  StreamController<List<Map<String, dynamic>>>.broadcast();

  bool _isActive = false;
  bool _isFetching = false;

  RunnerPollingService({required this.client});

  Stream<List<Map<String, dynamic>>> get events => _eventController.stream;
  bool get isActive => _isActive;

  Future<void> startPolling({
    required String query,
    Duration interval = const Duration(seconds: 5),
  }) async {
    if (_isActive) return;

    debugPrint('[RunnerPolling] Starting mission watch...');
    await stopPolling();

    _isActive = true;

    // Immediate first check
    _pollPendingOffers(query);

    _pollingTimer = Timer.periodic(interval, (_) => _pollPendingOffers(query));
  }

  Future<void> _pollPendingOffers(String query) async {
    if (!_isActive || _isFetching) return;

    _isFetching = true;

    try {
      final QueryOptions options = QueryOptions(
        document: gql(query),
        fetchPolicy: FetchPolicy.networkOnly,
        // Ensure data is fresh from the DB
      );

      final QueryResult result = await client.query(options).timeout(const Duration(seconds: 12));

      if (result.hasException) {
        debugPrint('[RunnerPolling] GraphQL error: ${result.exception}');
        return;
      }

      final List<dynamic>? rawOffers = result.data?['myPendingOffers'] as List<dynamic>?;
      final offersList = (rawOffers ?? [])
          .map((o) => Map<String, dynamic>.from(o as Map))
          .toList();

      // Detection of NEW offers for UI feedback (sound/vibration)
      _checkForNewOffers(offersList);

      if (!_eventController.isClosed) {
        _eventController.add(offersList);
      }

    } catch (e) {
      debugPrint('[RunnerPolling] Error: $e');
    } finally {
      _isFetching = false;
    }
  }

  void _checkForNewOffers(List<Map<String, dynamic>> currentOffers) {
    bool hasNew = false;
    for (var offer in currentOffers) {
      final id = offer['id'].toString();
      if (!_notifiedOfferIds.contains(id)) {
        _notifiedOfferIds.add(id);
        hasNew = true;
      }
    }

    if (hasNew) {
      debugPrint('[RunnerPolling] 🔔 NEW OFFER DETECTED!');
      // You can trigger HapticFeedback.vibrate() here or a custom event
    }

    // Cleanup: Remove IDs that are no longer in the list to keep memory clean
    final currentIds = currentOffers.map((o) => o['id'].toString()).toSet();
    _notifiedOfferIds.retainAll(currentIds);
  }

  Future<void> stopPolling() async {
    debugPrint('[RunnerPolling] Stopping mission watch...');
    _isActive = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> dispose() async {
    await stopPolling();
    await _eventController.close();
  }
}