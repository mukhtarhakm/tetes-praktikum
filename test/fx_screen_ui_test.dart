import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetes_praktikum/app/app_controller.dart';
import 'package:tetes_praktikum/app/app_theme.dart';
import 'package:tetes_praktikum/data/currencies.dart';
import 'package:tetes_praktikum/data/services.dart';
import 'package:tetes_praktikum/screens/explore_screen.dart';

class _FxController extends AppController {
  @override
  Future<FxQuote> rate(String currency) async =>
      FxQuote(currency, 18245, '2026-11-13');
}

void main() {
  test('daftar mata uang mencakup pilihan di luar tiga mata uang lama', () {
    expect(currencyNames.length, 30);
    expect(
      currencyNames.keys,
      containsAll(['IDR', 'SGD', 'MYR', 'THB', 'KRW']),
    );
  });

  testWidgets('cari mata uang dan tampilkan hasil rupiah pada layar kecil', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: FxScreen(controller: _FxController()),
      ),
    );
    await tester.tap(find.text('USD'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Singapura');
    await tester.pumpAndSettle();
    await tester.tap(find.text('SGD'));
    await tester.pumpAndSettle();

    expect(find.text('SGD'), findsOneWidget);
    await tester.tap(find.text('Cek kurs terbaru'));
    await tester.pumpAndSettle();
    expect(find.text('Rp 182.450'), findsOneWidget);
    expect(find.text('10 SGD × Rp 18.245'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextField).first, '20');
    await tester.pumpAndSettle();
    expect(find.text('Rp 182.450'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '10,5');
    await tester.tap(find.text('Cek kurs terbaru'));
    await tester.pumpAndSettle();
    expect(find.text('10,5 SGD × Rp 18.245'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
