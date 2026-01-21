// language: dart
// File: lib/controllers/my_errands_controller.dart

import 'package:get/get.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../services/graphql_client.dart';
import '../services/errand_service.dart';
import '../models/errand.dart';

class MyErrandsController extends GetxController {
  final GraphQLClient gqlClient;
  final dynamic socketService; // ErrandSocketService
  final int? userId;

  MyErrandsController({
    GraphQLClient? gqlClient,
    this.socketService,
    this.userId,
  }) : gqlClient = gqlClient ?? GraphQLClientInstance.client;

  final RxList<Map<String, dynamic>> offers = <Map<String, dynamic>>[].obs;

  // Errands state used by the UI
  final RxList<Errand> errands = <Errand>[].obs;
  final isLoading = false.obs;
  final errorMessage = RxnString();

  // Filter state
  final selectedFilter = Rxn<ErrandStatus>();

  final ErrandService _errandService = ErrandService();

  @override
  void onInit() {
    super.onInit();
    if (socketService != null && userId != null) {
      try {
        socketService.connect(userId: userId);
        socketService.events.listen(_handleSocketEvent);
      } catch (_) {}
    }

    // Initial fetch
    fetchErrands();
  }

  void _handleSocketEvent(Map<String, dynamic> event) {
    final type = event['type'];
    if (type == 'errand.offer') {
      // Ex: event contains offer_id, errand_id, position, expires_at
      final offer = {
        'offer_id': event['offer_id'],
        'errand_id': event['errand_id'],
        'position': event['position'],
        'expires_at': event['expires_at'],
        'raw': event,
      };
      offers.insert(0, offer);
      // Optionally notify UI (local notification / modal)
    }
  }

  /// Fetch errands from backend and populate state
  Future<void> fetchErrands() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final fetched = await _errandService.fetchMyErrands();
      errands.assignAll(fetched);
    } catch (e) {
      errorMessage.value = 'Failed to load errands: $e';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshErrands() async => fetchErrands();

  /// Returns errands filtered by status
  List<Errand> get filteredErrands {
    if (selectedFilter.value == null) return errands;
    return errands.where((e) => e.status == selectedFilter.value).toList();
  }

  void setFilter(ErrandStatus? status) => selectedFilter.value = status;

  /// Count helper for chips
  int getCountByStatus(ErrandStatus? status) {
    if (status == null) return errands.length;
    return errands.where((e) => e.status == status).length;
  }

  /// Cancel an errand and update local state
  Future<bool> cancelErrand(String errandId) async {
    try {
      await _errandService.cancelErrand(errandId);
      // mark as expired locally
      final idx = errands.indexWhere((e) => e.id == errandId);
      if (idx != -1) {
        final e = errands[idx];
        errands[idx] = Errand(
          id: e.id,
          type: e.type,
          tasks: e.tasks,
          speed: e.speed,
          paymentMethod: e.paymentMethod,
          goTo: e.goTo,
          returnTo: e.returnTo,
          imageUrl: e.imageUrl,
          status: ErrandStatus.expired,
          isOpen: false,
          createdAt: e.createdAt,
          expiresAt: e.expiresAt,
          runnerId: e.runnerId,
          runnerName: e.runnerName,
          price: e.price,
        );
      }
      errands.refresh();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> acceptOffer(int offerId) async {
    const String mutation = r'''
      mutation AcceptErrandOffer($offerId: ID!) {
        acceptErrandOffer(offerId: $offerId) {
          ok
        }
      }
    ''';

    final result = await gqlClient.mutate(MutationOptions(
      document: gql(mutation),
      variables: {'offerId': offerId.toString()},
      fetchPolicy: FetchPolicy.noCache,
    ));

    if (result.hasException) {
      return false;
    }

    final dynamic okRaw = result.data?['acceptErrandOffer']?['ok'];
    final bool ok = (okRaw is bool)
        ? okRaw
        : (okRaw is num)
            ? okRaw != 0
            : (okRaw?.toString().toLowerCase() == 'true' || okRaw?.toString() == '1');
    if (ok) {
      offers.removeWhere((o) => o['offer_id'] == offerId);
    }
    return ok;
  }

  @override
  void onClose() {
    socketService.disconnect();
    super.onClose();
  }
}
