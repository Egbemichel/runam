import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../../models/place_models.dart';
import '../models/errand_draft.dart';
import '../services/errand_service.dart';
import '../models/errand.dart';

class ErrandController extends GetxController {
  static const String _tag = '📦 [ErrandController]';

  final draft = ErrandDraft().obs;
  final selectedImage = Rxn<File>();

  // List of errands
  var errands = <Errand>[].obs;
  // Loading state
  var isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    debugPrint('$_tag Initializing ErrandController...');

    // Log draft changes
    ever(draft, (d) {
      debugPrint('$_tag Draft updated:');
      debugPrint('$_tag   Type: ${d.type}');
      debugPrint('$_tag   GoTo: ${d.goTo?.name}');
      debugPrint('$_tag   ReturnTo: ${d.returnTo?.name}');
      debugPrint('$_tag   Tasks: ${d.tasks.map((t) => t.description).join(', ')}');
      debugPrint('$_tag   Speed: ${d.speed}');
      debugPrint('$_tag   Payment: ${d.paymentMethod}');
      debugPrint('$_tag   IsComplete: ${d.isComplete}');
    });

    ever(selectedImage, (img) {
      debugPrint('$_tag Image ${img != null ? "selected" : "cleared"}: ${img?.path}');
    });
    fetchMyErrands();
  }

  void setType(String type) {
    debugPrint('$_tag setType called: $type');
    draft.update((d) {
      d!.type = type == "Round-trip" ? "ROUND_TRIP" : "ONE_WAY";
      if (d.type == "ONE_WAY") d.returnTo = null;
    });
    debugPrint('$_tag Type set to: ${draft.value.type}');
  }

  void setGoTo(Place location) {
    debugPrint('$_tag setGoTo called: ${location.name} (${location.latitude}, ${location.longitude})');
    draft.update((d) => d!.goTo = location);
  }

  void setReturnTo(Place location) {
    debugPrint('$_tag setReturnTo called: ${location.name} (${location.latitude}, ${location.longitude})');
    draft.update((d) => d!.returnTo = location);
  }

  void setTasks(String text) {
    debugPrint('$_tag setTasks called: ${text.length} tasks');
    draft.update((d) {
      d!.tasks = [ErrandTaskDraft(
        description: text,
        price: 0, // Default price, can be updated later
      )];
    });
  }

  void setSpeed(String value) {
    debugPrint('$_tag setSpeed called: $value');
    draft.update((d) => d!.speed = value);
  }

  void setPayment(String value) {
    debugPrint('$_tag setPayment called: $value');
    draft.update((d) => d!.paymentMethod = value);
  }

  void setImage(File? image) {
    debugPrint('$_tag setImage called: ${image?.path ?? "null"}');
    selectedImage.value = image;
  }

  Future<void> createErrand() async {
    debugPrint('$_tag === CREATE ERRAND ===');
    debugPrint('$_tag Validating draft...');

    // Validate required fields
    assert(draft.value.goTo != null, 'GoTo location is required');
    assert(draft.value.tasks != null && draft.value.tasks!.isNotEmpty, 'Instructions are required');
    assert(draft.value.paymentMethod != null, 'Payment method is required');

    debugPrint('$_tag Assertions passed');
    debugPrint('$_tag Draft complete: ${draft.value.isComplete}');

    if (!draft.value.isComplete) {
      debugPrint('$_tag ❌ Errand is incomplete!');
      throw Exception("Errand is incomplete");
    }

    debugPrint('$_tag Calling ErrandService.createErrand...');
    debugPrint('$_tag Draft payload: ${draft.value.toJson()}');
    debugPrint('$_tag Has image: ${selectedImage.value != null}');

    // Create errand with optional image
    await Get.find<ErrandService>().createErrand(
      draft.value,
      image: selectedImage.value,
    );

    debugPrint('$_tag ✅ Errand created successfully!');
  }

  void reset() {
    debugPrint('$_tag Resetting draft and image...');
    draft.value = ErrandDraft();
    selectedImage.value = null;
    debugPrint('$_tag Reset complete');
  }

  /// Fetch errands for the authenticated user
  Future<void> fetchMyErrands() async {
    debugPrint('$_tag === FETCH MY ERRANDS ===');
    isLoading.value = true;

    try {
      debugPrint('$_tag Calling ErrandService.fetchMyErrands...');

      final List<Errand> fetchedErrands = await Get.find<ErrandService>().fetchMyErrands();

      debugPrint('$_tag ✅ Fetched ${fetchedErrands.length} errands from backend');

      // Update the observable list
      errands.value = fetchedErrands;

    } catch (e) {
      debugPrint('$_tag ❌ Failed to fetch errands: $e');
      errands.clear(); // clear previous errands on error
    } finally {
      isLoading.value = false;
      debugPrint('$_tag === FETCH MY ERRANDS: Finished ===');
    }
  }
}
