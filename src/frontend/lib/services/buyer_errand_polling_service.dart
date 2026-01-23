import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

class BuyerErrandPollingService {
  final GraphQLClient client;
  Timer? _pollingTimer;

  // FIXED: Corrected the .broadcast() syntax and generic types
  final StreamController<Map<String, dynamic>?> _statusController =
  StreamController<Map<String, dynamic>?>.broadcast();

  bool _isActive = false;
  bool _isFetching = false;

  BuyerErrandPollingService({required this.client});

  Stream<Map<String, dynamic>?> get statusStream => _statusController.stream;

  void startPolling({
    required String query,
    required String errandId,
    Duration interval = const Duration(seconds: 4),
  }) {
    if (_isActive) stopPolling();
    _isActive = true;

    debugPrint('[BuyerPolling] Monitoring Errand: $errandId');
    _poll(query, errandId);
    _pollingTimer = Timer.periodic(interval, (_) => _poll(query, errandId));
  }

  Future<void> _poll(String query, String errandId) async {
    if (!_isActive || _isFetching) return;
    _isFetching = true;

    try {
      final result = await client.query(QueryOptions(
        document: gql(query),
        variables: {'id': errandId},
        fetchPolicy: FetchPolicy.networkOnly,
      ));

      if (result.hasException) {
        debugPrint('[BuyerPolling] GQL Error: ${result.exception}');
        return;
      }

      if (result.data?['errand'] != null) {
        _statusController.add(result.data!['errand']);
      }
    } catch (e) {
      debugPrint('[BuyerPolling] Connection Error: $e');
    } finally {
      _isFetching = false;
    }
  }

  void stopPolling() {
    _isActive = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> dispose() async {
    stopPolling();
    await _statusController.close();
  }
}