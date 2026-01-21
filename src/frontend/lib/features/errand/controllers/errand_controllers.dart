import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import '../../../models/place_models.dart';
import '../../../controllers/location_controller.dart';
import '../../../services/auth_service.dart';
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

  Future<String> createErrand() async {
    debugPrint('$_tag === CREATE ERRAND: User triggered errand creation (slider) ===');
    debugPrint('$_tag [STEP] Validating draft before creation...');

    // Validate required fields
    assert(draft.value.goTo != null, 'GoTo location is required');
    assert(draft.value.tasks.isNotEmpty, 'Tasks are required');
    assert(draft.value.paymentMethod != null, 'Payment method is required');

    debugPrint('$_tag [STEP] Validation passed. Draft complete: ${draft.value.isComplete}');

    if (!draft.value.isComplete) {
      debugPrint('$_tag [ERROR] Errand is incomplete!');
      throw Exception("Errand is incomplete");
    }

    debugPrint('$_tag [STEP] Calling ErrandService.createErrand...');
    debugPrint('$_tag [DATA] Draft payload: ${draft.value.toJson()}');
    debugPrint('$_tag [DATA] Has image: ${selectedImage.value != null}');

    // --- Upsert user's current location before creating the errand ---
    try {
      final locController = Get.find<LocationController>();
      var locPayload = locController.toPayload();

      // If DEVICE mode but we don't have a currentPosition, attempt to fetch a one-shot GPS reading
      if (locPayload.isEmpty && locController.locationMode.value == LocationMode.device) {
        debugPrint('$_tag [STEP] No cached device position; attempting one-shot GPS read');
        try {
          final Position pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
          );
          locPayload = {
            'mode': 'DEVICE',
            'latitude': pos.latitude,
            'longitude': pos.longitude,
          };
          debugPrint('$_tag [STEP] One-shot GPS read success: $locPayload');
        } catch (e) {
          debugPrint('$_tag [WARN] One-shot GPS read failed: $e');
        }
      }

      if (locPayload.isNotEmpty) {
        final mode = locPayload['mode'] as String? ?? 'DEVICE';
        final latitude = (locPayload['latitude'] as num).toDouble();
        final longitude = (locPayload['longitude'] as num).toDouble();
        final address = locPayload['address'] as String?;

        debugPrint('$_tag [STEP] Updating user location to backend before errand creation: $locPayload');
        try {
          await Get.find<AuthService>().updateLocation(
            mode: mode,
            latitude: latitude,
            longitude: longitude,
            address: address,
          );
          debugPrint('$_tag [STEP] User location updated successfully');
        } catch (e) {
          debugPrint('$_tag [WARN] Failed to update user location before errand creation: $e');
          // proceed with errand creation even if location update fails
        }
      } else {
        debugPrint('$_tag [WARN] No valid location payload to send to backend before errand creation');
      }
    } catch (e) {
      debugPrint('$_tag [WARN] Could not fetch LocationController or build payload: $e');
    }

    try {
      final result = await Get.find<ErrandService>().createErrand(
        draft.value,
        image: selectedImage.value,
      );
      final String? errandId = result['errandId']?.toString();
      debugPrint('$_tag [STEP] ErrandService.createErrand completed. New errandId: $errandId');
      if (errandId == null) {
        throw Exception('No errandId returned from service');
      }
      return errandId;
    } catch (e) {
      debugPrint('$_tag [ERROR] Exception during errand creation: $e');
      rethrow;
    }
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
