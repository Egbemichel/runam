import 'dart:async';

import 'package:get/get.dart';

import '../models/errand.dart';
import '../services/errand_service.dart';

/// Controller for managing user's errands with filtering and real-time updates
class MyErrandsController extends GetxController {
  final ErrandService _errandService = Get.find<ErrandService>();

  // All errands
  final errands = <Errand>[].obs;

  // Loading state
  final isLoading = false.obs;

  // Error message
  final errorMessage = RxnString();

  // Selected filter
  final selectedFilter = Rx<ErrandStatus?>(null);

  // Timer for checking expiry
  Timer? _expiryCheckTimer;

  @override
  void onInit() {
    super.onInit();
    fetchErrands();
    _startExpiryCheck();
  }

  @override
  void onClose() {
    _expiryCheckTimer?.cancel();
    super.onClose();
  }

  /// Start periodic check for expired errands
  void _startExpiryCheck() {
    _expiryCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkExpiredErrands(),
    );
  }

  /// Check and update expired errands locally
  void _checkExpiredErrands() {
    final now = DateTime.now();
    bool hasChanges = false;

    for (int i = 0; i < errands.length; i++) {
      final errand = errands[i];
      // If errand is pending and has expired, update its status
      if (errand.status == ErrandStatus.pending &&
          errand.isOpen &&
          now.isAfter(errand.expiresAt)) {
        errands[i] = errand.copyWith(
          status: ErrandStatus.expired,
          isOpen: false,
        );
        hasChanges = true;
      }
    }

    if (hasChanges) {
      errands.refresh();
    }
  }

  /// Fetch all errands for the current user
  Future<void> fetchErrands() async {
    try {
      isLoading.value = true;
      errorMessage.value = null;

      final fetchedErrands = await _errandService.fetchMyErrands();
      errands.assignAll(fetchedErrands);

      // Check for any already expired errands
      _checkExpiredErrands();
    } catch (e) {
      errorMessage.value = 'Failed to load errands: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// Get errands filtered by status
  List<Errand> get filteredErrands {
    if (selectedFilter.value == null) {
      return errands;
    }
    return errands.where((e) => e.status == selectedFilter.value).toList();
  }

  /// Get pending errands (searching for runner)
  List<Errand> get pendingErrands =>
      errands.where((e) => e.status == ErrandStatus.pending).toList();

  /// Get accepted/in-progress errands
  List<Errand> get acceptedErrands =>
      errands.where((e) => e.status == ErrandStatus.accepted).toList();

  /// Get completed errands
  List<Errand> get completedErrands =>
      errands.where((e) => e.status == ErrandStatus.completed).toList();

  /// Get expired errands
  List<Errand> get expiredErrands =>
      errands.where((e) => e.status == ErrandStatus.expired).toList();

  /// Get cancelled errands
  List<Errand> get cancelledErrands =>
      errands.where((e) => e.status == ErrandStatus.cancelled).toList();

  /// Get count by status
  int getCountByStatus(ErrandStatus? status) {
    if (status == null) return errands.length;
    return errands.where((e) => e.status == status).length;
  }

  /// Set filter
  void setFilter(ErrandStatus? status) {
    selectedFilter.value = status;
  }

  /// Cancel an errand
  Future<bool> cancelErrand(String errandId) async {
    try {
      await _errandService.cancelErrand(errandId);

      // Update local state
      final index = errands.indexWhere((e) => e.id == errandId);
      if (index != -1) {
        errands[index] = errands[index].copyWith(
          status: ErrandStatus.cancelled,
          isOpen: false,
        );
        errands.refresh();
      }

      return true;
    } catch (e) {
      errorMessage.value = 'Failed to cancel errand: $e';
      return false;
    }
  }

  /// Refresh errands from server
  Future<void> refresh() async {
    await fetchErrands();
  }
}

