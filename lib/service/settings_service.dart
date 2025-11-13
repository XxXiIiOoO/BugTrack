import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  static const defaultLanguageCode = 'ru';
  static const supportedLanguageCodes = ['ru', 'en'];

  late SharedPreferences _prefs;
  ThemeMode themeMode = ThemeMode.dark;
  String defaultStatusFilter = ''; // '', 'Open', 'In Progress', 'Done'
  bool notificationsEnabled = true;
  Locale locale = const Locale(defaultLanguageCode);

  String get languageCode => locale.languageCode;
  List<Locale> get supportedLocales =>
      supportedLanguageCodes.map((code) => Locale(code)).toList(growable: false);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final tmIndex = _prefs.getInt('themeMode') ?? 2; // 0=system,1=light,2=dark
    themeMode = ThemeMode.values[tmIndex];
    defaultStatusFilter = _prefs.getString('defaultStatus') ?? '';
    notificationsEnabled = _prefs.getBool('notif') ?? true;
    final langCode = _prefs.getString('locale') ?? defaultLanguageCode;
    locale = Locale(langCode);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    await _prefs.setInt('themeMode', ThemeMode.values.indexOf(mode));
    notifyListeners();
  }

  Future<void> setDefaultStatus(String v) async {
    defaultStatusFilter = v;
    await _prefs.setString('defaultStatus', v);
    notifyListeners();
  }

  Future<void> setNotifications(bool v) async {
    notificationsEnabled = v;
    await _prefs.setBool('notif', v);
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    if (!supportedLanguageCodes.contains(code)) return;
    locale = Locale(code);
    await _prefs.setString('locale', code);
    notifyListeners();
  }

  Future<void> reset() async {
    await _prefs.remove('themeMode');
    await _prefs.remove('defaultStatus');
    await _prefs.remove('notif');
    await _prefs.remove('locale');
    await init();
    notifyListeners();
  }
}
