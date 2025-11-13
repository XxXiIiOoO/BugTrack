// lib/services/saved_filters.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SavedFilters {
  SavedFilters._();
  static final SavedFilters instance = SavedFilters._();

  Future<void> save(String name, Map<String, dynamic> query) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('filter_$name', jsonEncode(query));
  }

  Future<Map<String, dynamic>?> load(String name) async {
    final sp = await SharedPreferences.getInstance();
    final s = sp.getString('filter_$name');
    if (s == null) return null;
    return jsonDecode(s) as Map<String, dynamic>;
  }

  Future<List<String>> listNames() async {
    final sp = await SharedPreferences.getInstance();
    return sp
        .getKeys()
        .where((k) => k.startsWith('filter_'))
        .map((k) => k.substring('filter_'.length))
        .toList();
  }

  Future<void> delete(String name) async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove('filter_$name');
  }
}
