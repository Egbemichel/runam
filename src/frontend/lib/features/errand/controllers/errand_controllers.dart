import 'dart:io';

import 'package:get/get.dart';

import '../../../models/place_models.dart';
import '../models/errand_draft.dart';
import '../services/errand_service.dart';

class ErrandController extends GetxController {
  final draft = ErrandDraft().obs;
  final selectedImage = Rxn<File>();

  void setType(String type) {
    draft.update((d) {
      d!.type = type == "Round-trip" ? "ROUND_TRIP" : "ONE_WAY";
      if (d.type == "ONE_WAY") d.returnTo = null;
    });
  }

  void setGoTo(Place location) {
    draft.update((d) => d!.goTo = location);
  }

  void setReturnTo(Place location) {
    draft.update((d) => d!.returnTo = location);
  }

  void setInstructions(String text) {
    draft.update((d) => d!.instructions = text);
  }

  void setSpeed(String value) {
    draft.update((d) => d!.speed = value);
  }

  void setPayment(String value) {
    draft.update((d) => d!.paymentMethod = value);
  }

  void setImage(File? image) {
    selectedImage.value = image;
  }

  Future<void> createErrand() async {
    if (!draft.value.isComplete) {
      throw Exception("Errand is incomplete");
    }

    // Create errand with optional image
    await Get.find<ErrandService>().createErrand(
      draft.value,
      image: selectedImage.value,
    );
  }

  void reset() {
    draft.value = ErrandDraft();
    selectedImage.value = null;
  }
}
