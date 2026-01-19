// lib/services/errand_polling_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

class ErrandPollingService {
  final GraphQLClient client;
  Timer? _pollingTimer;
  final StreamController<Map<String, dynamic>> _eventController = StreamController.broadcast();

  bool _isActive = false;
  bool _isFetching = false; // Guard to prevent overlapping requests
  String? _currentErrandId;

  ErrandPollingService({required this.client});

  Stream<Map<String, dynamic>> get events => _eventController.stream;
  bool get isActive => _isActive;

  Future<void> startPolling({
    required String errandId,
    required String query,
    Duration interval = const Duration(seconds: 3),
  }) async {
    if (_isActive && _currentErrandId == errandId) return;

    debugPrint('[Polling] Starting for errand: $errandId');
    await stopPolling();

    _isActive = true;
    _currentErrandId = errandId;

    // Initial immediate call
    _pollErrandStatus(errandId, query);

    _pollingTimer = Timer.periodic(interval, (_) => _pollErrandStatus(errandId, query));
  }

  Future<void> _pollErrandStatus(String errandId, String query) async {
    // 1. Guard against overlapping calls or inactive state
    if (!_isActive || _isFetching) return;

    _isFetching = true;

    try {
      final QueryOptions options = QueryOptions(
        document: gql(query),
        variables: {'id': errandId},
        fetchPolicy: FetchPolicy.networkOnly,
        // Ensure we don't wait forever on a hanging connection
        pollInterval: null,
      );

      final QueryResult result = await client.query(options).timeout(const Duration(seconds: 10));

      if (result.hasException) {
        debugPrint('[Polling] GraphQL error: ${result.exception}');
        return;
      }

      final data = result.data?['errand'] as Map<String, dynamic>?;
      if (data == null) return;

      final String status = data['status'] ?? 'PENDING';

      // 2. Emit data to UI
      if (!_eventController.isClosed) {
        _eventController.add({
          'type': 'errand.status_update',
          'errand_id': errandId,
          'status': status,
          'data': data,
        });
      }

      // 3. AUTO-STOP: If the errand is no longer pending, we stop polling automatically
      // Terminal states: ACCEPTED, IN_PROGRESS, COMPLETED, CANCELLED, EXPIRED
      if (status != 'PENDING') {
        debugPrint('[Polling] Errand reached terminal state ($status). Stopping polling.');
        stopPolling();
      }

    } catch (e) {
      debugPrint('[Polling] Critical Error: $e');
    } finally {
      _isFetching = false;
    }
  }

  Future<void> stopPolling() async {
    _isActive = false;
    _currentErrandId = null;
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> dispose() async {
    await stopPolling();
    await _eventController.close();
  }
}