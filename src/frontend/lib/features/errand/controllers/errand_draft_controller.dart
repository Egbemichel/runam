import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/errand_draft.dart';
import '../services/errand_service.dart';

class ErrandDraftController extends GetxController {
  static const String _tag = '📝 [ErrandDraftController]';
  static const _storageKey = "errand_draft";

  final draft = ErrandDraft().obs;
  SharedPreferences? _prefs;
  ErrandService? _api;
  final _isInitialized = false.obs;

  @override
  void onInit() {
    super.onInit();
    debugPrint('$_tag Initializing ErrandDraftController...');
    _initAsync();
  }

  Future<void> _initAsync() async {
    debugPrint('$_tag Loading SharedPreferences...');
    _prefs = await SharedPreferences.getInstance();
    _api = Get.find<ErrandService>();
    loadDraft();
    _isInitialized.value = true;
    debugPrint('$_tag Initialization complete');
  }

  bool get isInitialized => _isInitialized.value;

  void loadDraft() {
    debugPrint('$_tag Loading draft from storage...');
    if (_prefs == null) {
      debugPrint('$_tag SharedPreferences not ready');
      return;
    }

    final raw = _prefs!.getString(_storageKey);
    if (raw != null) {
      try {
        draft.value = ErrandDraft.fromJson(jsonDecode(raw));
        debugPrint('$_tag Draft loaded successfully:');
        debugPrint('$_tag   Type: ${draft.value.type}');
        debugPrint('$_tag   GoTo: ${draft.value.goTo?.name}');
        debugPrint('$_tag   Tasks: ${draft.value.tasks.length} tasks');
        debugPrint('$_tag   Speed: ${draft.value.speed}');
        debugPrint('$_tag   Payment: ${draft.value.paymentMethod}');
      } catch (e) {
        debugPrint('$_tag Error loading draft: $e');
        draft.value = ErrandDraft();
      }
    } else {
      debugPrint('$_tag No saved draft found');
    }
  }

  void saveLocal() {
    debugPrint('$_tag Saving draft to local storage...');
    if (_prefs == null) {
      debugPrint('$_tag SharedPreferences not ready, cannot save');
      return;
    }

    final json = jsonEncode(draft.value.toJson());
    _prefs!.setString(_storageKey, json);
    debugPrint('$_tag Draft saved successfully');
    debugPrint('$_tag Saved data: $json');
  }

  void updateDraft(void Function(ErrandDraft d) updater) {
    debugPrint('$_tag Updating draft...');
    updater(draft.value);
    draft.refresh();
    saveLocal();
    debugPrint('$_tag Draft updated and saved');
  }

  Future<void> syncRemote() async {
    debugPrint('$_tag Syncing draft to remote server...');
    if (_api == null) {
      debugPrint('$_tag API not ready, cannot sync');
      return;
    }

    final result = await _api!.saveErrandDraft(draft.value.toJson());
    draft.value.id = result["id"];
    saveLocal();
    debugPrint('$_tag Draft synced, ID: ${draft.value.id}');
  }

  Future<void> clearDraft() async {
    debugPrint('$_tag Clearing draft...');
    if (_prefs != null) {
      await _prefs!.remove(_storageKey);
      debugPrint('$_tag Draft removed from storage');
    }
    draft.value = ErrandDraft();
    debugPrint('$_tag Draft cleared');
  }
}
