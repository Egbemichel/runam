import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/errand_draft.dart';
import '../services/errand_service.dart';

class ErrandDraftController extends GetxController {
  static const _storageKey = "errand_draft";

  final draft = ErrandDraft().obs;
  late final SharedPreferences _prefs;
  late final ErrandService _api;

  @override
  void onInit() async {
    super.onInit();
    _prefs = await SharedPreferences.getInstance();
    _api = Get.find<ErrandService>();
    loadDraft();
  }

  void loadDraft() {
    final raw = _prefs.getString(_storageKey);
    if (raw != null) {
      draft.value = ErrandDraft.fromJson(jsonDecode(raw));
    }
  }

  void saveLocal() {
    _prefs.setString(_storageKey, jsonEncode(draft.value.toJson()));
  }

  void updateDraft(void Function(ErrandDraft d) updater) {
    updater(draft.value);
    draft.refresh();
    saveLocal();
  }

  Future<void> syncRemote() async {
    final result = await _api.saveErrandDraft(draft.value.toJson());
    draft.value.id = result["id"];
    saveLocal();
  }

  Future<void> clearDraft() async {
    await _prefs.remove(_storageKey);
    draft.value = ErrandDraft();
  }
}
