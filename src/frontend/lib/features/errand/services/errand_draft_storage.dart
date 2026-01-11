import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/errand_draft.dart';

class ErrandDraftStorage {
  static const _key = 'errand_draft';

  Future<void> save(ErrandDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(draft.toJson()));
  }

  Future<ErrandDraft?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    return ErrandDraft.fromJson(jsonDecode(raw));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
