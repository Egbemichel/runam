// lib/controllers/buyer_tracking_controller.dart
import 'dart:async';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../services/buyer_errand_polling_service.dart';
import '../services/graphql_client.dart';
import '../app/router.dart'; // Contains rootNavigatorKey

class BuyerTrackingController extends GetxService {
  BuyerErrandPollingService? _service;
  StreamSubscription? _sub;

  final RxnString activeErrandId = RxnString();
  final RxString currentStatus = ''.obs;

  void monitorErrand(String errandId) {
    activeErrandId.value = errandId;

    // Initialize service if not exists or recreate with fresh client
    _service?.dispose();
    _sub?.cancel();

    _service = BuyerErrandPollingService(client: GraphQLClientInstance.client);

    // Start the engine
    _service!.startPolling(
      query: r'''
        query GetErrandStatus($id: ID!) {
          errand(id: $id) {
            id
            status
            runnerId
            runnerName
            imageUrl
          }
        }
      ''',
      errandId: errandId,
    );

    // Listen to the results
    _sub = _service!.statusStream.listen((data) {
      if (data == null) return;

      final String status = data['status'] ?? '';
      currentStatus.value = status;

      if (status == 'ACCEPTED' || status == 'IN_PROGRESS') {
        _handleSuccessNavigation(data);
      } else if (status == 'CANCELLED' || status == 'EXPIRED') {
        _handleTermination(status);
      }
    });
  }

  void _handleSuccessNavigation(Map<String, dynamic> data) {
    stopMonitoring();
    final context = rootNavigatorKey.currentContext;
    if (context != null) {
      context.go('/errand-in-progress', extra: {...data, 'isRunner': false});
    }
  }

  void _handleTermination(String status) {
    stopMonitoring();
    Get.snackbar("Errand Alert", "Your errand was $status");
  }

  void stopMonitoring() {
    _service?.stopPolling();
    activeErrandId.value = null;
  }
}