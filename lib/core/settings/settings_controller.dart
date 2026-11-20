import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

class SettingsController extends Notifier<AppSettings> {
  SharedPreferences? _preferences;

  @override
  AppSettings build() {
    _load();
    return const AppSettings();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _preferences = p;
    state = AppSettings(
      themeMode: ThemeMode.values[p.getInt('theme') ?? 0],
      locale: Locale(p.getString('locale') ?? 'ar'),
      amoled: p.getBool('amoled') ?? false,
      highContrast: p.getBool('contrast') ?? false,
      reduceMotion: p.getBool('motion') ?? false,
      autosaveSeconds: p.getInt('autosave') ?? 12,
      editorFontSize: p.getDouble('fontSize') ?? 18,
      defaultRtl: p.getBool('rtl') ?? true,
      onboardingDone: p.getBool('onboarded') ?? false,
    );
  }

  Future<void> update(AppSettings next) async {
    state = next;
    final p = _preferences ?? await SharedPreferences.getInstance();
    await Future.wait([
      p.setInt('theme', next.themeMode.index),
      p.setString('locale', next.locale.languageCode),
      p.setBool('amoled', next.amoled),
      p.setBool('contrast', next.highContrast),
      p.setBool('motion', next.reduceMotion),
      p.setInt('autosave', next.autosaveSeconds),
      p.setDouble('fontSize', next.editorFontSize),
      p.setBool('rtl', next.defaultRtl),
      p.setBool('onboarded', next.onboardingDone),
    ]);
  }
}
