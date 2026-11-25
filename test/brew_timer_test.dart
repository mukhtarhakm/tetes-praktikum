import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetes_praktikum/app/app_controller.dart';
import 'package:tetes_praktikum/app/app_theme.dart';
import 'package:tetes_praktikum/data/brew_session_progress.dart';
import 'package:tetes_praktikum/data/models.dart';
import 'package:tetes_praktikum/screens/brew_screen.dart';

void main() {
  final plan = BrewPlan(
    beanId: 'bean',
    beanName: 'Kopi uji',
    doseG: 15,
    ratio: 15,
    temperatureC: 92,
    grind: 'Sedang',
    pouringCount: 3,
    customStages: BrewPlan.defaultPourStages(15, 15, 3),
  );

  test('waktu total maju dan progres dimulai lagi pada tiap tuangan', () {
    final first = BrewSessionProgress(plan, 20);
    expect(first.stageIndex, 0);
    expect(first.stageProgress, 0.5);
    expect(first.cumulativeWaterAt(0), 45);

    final second = BrewSessionProgress(plan, 40);
    expect(second.elapsedSeconds, 40);
    expect(second.stageIndex, 1);
    expect(second.stageElapsedSeconds, 0);
    expect(second.stageProgress, 0);
    expect(second.cumulativeWaterAt(1), 135);

    final third = BrewSessionProgress(plan, 70);
    expect(third.stageIndex, 2);
    expect(third.stageProgress, 0);
    expect(third.cumulativeWaterAt(2), 225);
  });

  test('drawdown menghitung maju setelah tuangan terakhir', () {
    final drawdown = BrewSessionProgress(plan, 100);
    expect(drawdown.isDrawdown, isTrue);
    expect(drawdown.stageProgress, isNull);
    expect(drawdown.drawdownElapsedSeconds, 0);
    expect(BrewSessionProgress(plan, 112).drawdownElapsedSeconds, 12);
  });

  testWidgets('sesi menampilkan jam total dan progres tuangan pertama', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BrewSessionScreen(controller: AppController(), plan: plan),
      ),
    );
    expect(find.text('WAKTU TOTAL'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('TUANGAN 1 DARI 3'), findsOneWidget);
    expect(find.text('Tuangan ini 00:00 / 00:40'), findsOneWidget);
    final ring = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(ring.color, AppColors.pourColors.first);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('bunyi tahap tersedia dan suara serta getar dapat dimatikan', (
    tester,
  ) async {
    expect(
      (await rootBundle.load('assets/audio/pour.wav')).lengthInBytes,
      greaterThan(0),
    );
    expect(
      (await rootBundle.load('assets/audio/drawdown.wav')).lengthInBytes,
      greaterThan(0),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BrewSessionScreen(controller: AppController(), plan: plan),
      ),
    );
    await tester.tap(find.byTooltip('Matikan suara dan getar'));
    await tester.pump();
    expect(find.byTooltip('Aktifkan suara dan getar'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
