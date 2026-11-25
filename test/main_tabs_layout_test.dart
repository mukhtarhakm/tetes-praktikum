import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetes_praktikum/app/app_controller.dart';
import 'package:tetes_praktikum/app/app_theme.dart';
import 'package:tetes_praktikum/screens/home_screen.dart';

void main() {
  testWidgets('tab utama tetap terbaca di layar sempit', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(controller: AppController()),
      ),
    );
    for (final tab in ['Beans', 'Jurnal', 'Lainnya']) {
      await tester.tap(find.text(tab).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Tab $tab overflow');
    }
    expect(find.text('Akun dan peralatan'), findsOneWidget);
    expect(find.text('Kelola akun dan pengingat'), findsOneWidget);
    expect(find.text('Pengingat seduh'), findsNothing);
  });
}
