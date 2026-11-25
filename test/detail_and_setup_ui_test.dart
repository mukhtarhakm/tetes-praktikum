import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetes_praktikum/app/app_controller.dart';
import 'package:tetes_praktikum/app/app_theme.dart';
import 'package:tetes_praktikum/data/models.dart';
import 'package:tetes_praktikum/data/services.dart';
import 'package:tetes_praktikum/screens/brew_screen.dart';
import 'package:tetes_praktikum/screens/journal_screen.dart';

class SampleController extends AppController {
  @override
  List<Bean> get beans => const [
    Bean(
      id: 'bean',
      name: 'kamojang mekar',
      roastery: 'the creator',
      origin: 'West Java',
      stockG: 185,
      price: 320000,
      currency: 'IDR',
      tastingNotes: '',
    ),
  ];

  @override
  List<BrewEntry> get brews => [
    BrewEntry(
      id: 'brew',
      plan: BrewPlan(
        beanId: 'bean',
        beanName: 'kamojang mekar',
        doseG: 15,
        ratio: 16,
        temperatureC: 92,
        grind: 'Sedang',
        pouringCount: 3,
        customStages: BrewPlan.defaultPourStages(15, 16, 3),
      ),
      brewedAt: DateTime(2026, 11, 15),
      durationS: 100,
      score: 3,
      notes: '',
    ),
  ];

  @override
  Future<AiRecommendation> recommend(
    Bean bean,
    AiPreferences preferences,
  ) async => AiRecommendation.fromMap({
    'dose_g': 15,
    'ratio': 16,
    'temperature_c': 94,
    'grind': 'Sedang',
    'pouring_count': 3,
    'stages': [
      {'duration_s': 40, 'water_g': 45},
      {'duration_s': 35, 'water_g': 105},
      {'duration_s': 35, 'water_g': 90},
    ],
    'note': 'Coba untuk rasa lebih manis.',
  });
}

class ReplayController extends SampleController {
  @override
  List<BrewEntry> get brews => [
    BrewEntry(
      id: 'brew',
      plan: const BrewPlan(
        beanId: 'bean',
        beanName: 'kamojang mekar',
        doseG: 18,
        ratio: 15,
        temperatureC: 90,
        grind: 'Kasar',
        pouringCount: 2,
        customStages: [
          BrewStage('Pouring 1 · Bloom', 50, 54),
          BrewStage('Pouring 2', 40, 216),
        ],
      ),
      brewedAt: DateTime(2026, 11, 15),
      durationS: 120,
      score: 5,
      notes: 'Sedikit pahit',
      aiDiagnosis: const AiDiagnosis(
        text: 'Coba suhu lebih rendah.',
        note: 'Turunkan suhu untuk eksperimen berikutnya.',
        nextPlan: BrewPlan(
          beanId: 'bean',
          beanName: 'kamojang mekar',
          doseG: 18,
          ratio: 14,
          temperatureC: 88,
          grind: 'Kasar',
          pouringCount: 2,
          customStages: [
            BrewStage('Pouring 1 · Bloom', 50, 54),
            BrewStage('Pouring 2', 40, 198),
          ],
        ),
      ),
    ),
  ];
}

void main() {
  testWidgets('filter jurnal dapat dipilih dan direset', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: JournalScreen(controller: SampleController())),
      ),
    );
    await tester.tap(find.byTooltip('Saring jurnal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 ★'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tampilkan 0 seduhan'));
    await tester.pumpAndSettle();
    expect(find.text('Seduhan tidak ditemukan.'), findsOneWidget);
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.text('kamojang mekar'), findsOneWidget);
  });

  testWidgets('resep jurnal dan saran diagnosis membuka rencana yang tepat', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BrewDetailScreen(controller: ReplayController(), brewId: 'brew'),
      ),
    );
    await tester.ensureVisible(find.text('Seduh lagi dengan resep ini'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seduh lagi dengan resep ini'));
    await tester.pumpAndSettle();
    expect(find.text('270 g'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('00:00 - 00:50'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('00:00 - 00:50'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Coba saran AI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coba saran AI'));
    await tester.pumpAndSettle();
    expect(find.text('Saran AI'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('252 g'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('252 g'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('menutup panel saran AI dengan geser tidak merusak layar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BrewSetupScreen(controller: SampleController()),
      ),
    );
    await tester.tap(find.text('Minta saran AI'));
    await tester.pumpAndSettle();
    expect(find.text('Saran untuk kamojang mekar'), findsOneWidget);
    final sheet = find.byType(BottomSheet);
    final handle = tester.getTopLeft(sheet) + const Offset(190, 12);
    await tester.dragFrom(handle, const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(find.text('Saran untuk kamojang mekar'), findsNothing);
    expect(find.text('Rencana seduhmu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kartu saran AI menampilkan rencana yang diterapkan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BrewSetupScreen(controller: SampleController()),
      ),
    );
    await tester.tap(find.text('Minta saran AI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buat saran'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Tinjau rencana AI'), findsOneWidget);
    await tester.tap(find.text('Terapkan'));
    await tester.pumpAndSettle();
    expect(find.text('Saran AI'), findsOneWidget);
    expect(find.text('Bloom: 40 detik · 45 g'), findsOneWidget);
    expect(find.text('Tuangan 2: 35 detik · 105 g'), findsOneWidget);
    expect(find.text('Coba untuk rasa lebih manis.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ubah durasi memperbarui rentang tanpa error saat dialog ditutup',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BrewSetupScreen(controller: SampleController()),
        ),
      );
      expect(find.text('240 g'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('00:00 - 00:40'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('00:00 - 00:40'), findsOneWidget);

      final edit = find.text('Ubah durasi atau air').first;
      await tester.ensureVisible(edit);
      await tester.pumpAndSettle();
      await tester.tap(edit);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Batal'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      final inputs = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(inputs.first, '50');
      await tester.tap(find.widgetWithText(TextButton, 'Simpan'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('00:00 - 00:50'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('00:50 - 01:20'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('00:50 - 01:20'), findsOneWidget);
    },
  );

  testWidgets('detail seduhan ringkas saat catatan tambahan kosong', (
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
        home: BrewDetailScreen(controller: SampleController(), brewId: 'brew'),
      ),
    );
    expect(find.text('kamojang mekar'), findsOneWidget);
    expect(find.text('3/5'), findsOneWidget);
    expect(find.text('240 g'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Belum ada catatan rasa atau pengukuran tambahan.'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Belum ada catatan rasa atau pengukuran tambahan.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
