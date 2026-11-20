import 'package:flutter/material.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.dark,
    this.locale = const Locale('ar'),
    this.amoled = false,
    this.highContrast = false,
    this.reduceMotion = false,
    this.autosaveSeconds = 12,
    this.editorFontSize = 18,
    this.defaultRtl = true,
    this.onboardingDone = false,
  });

  final ThemeMode themeMode;
  final Locale locale;
  final bool amoled;
  final bool highContrast;
  final bool reduceMotion;
  final int autosaveSeconds;
  final double editorFontSize;
  final bool defaultRtl;
  final bool onboardingDone;

  AppSettings copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool? amoled,
    bool? highContrast,
    bool? reduceMotion,
    int? autosaveSeconds,
    double? editorFontSize,
    bool? defaultRtl,
    bool? onboardingDone,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      amoled: amoled ?? this.amoled,
      highContrast: highContrast ?? this.highContrast,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      autosaveSeconds: autosaveSeconds ?? this.autosaveSeconds,
      editorFontSize: editorFontSize ?? this.editorFontSize,
      defaultRtl: defaultRtl ?? this.defaultRtl,
      onboardingDone: onboardingDone ?? this.onboardingDone,
    );
  }
}
