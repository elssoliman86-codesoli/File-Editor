import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:midad/app.dart';

void main() {
  testWidgets('shows an honest empty workspace and Arabic navigation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboarded': true});
    await tester.pumpWidget(const ProviderScope(child: MidadApp()));
    await tester.pump();
    expect(find.text('مِداد'), findsWidgets);
    expect(find.text('لا توجد مستندات بعد'), findsOneWidget);
    expect(find.text('المستندات'), findsOneWidget);
    expect(find.text('أدوات PDF'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(find.text('الإعدادات').last);
    await tester.pumpAndSettle();
    expect(find.text('المظهر'), findsWidgets);
  });
}
