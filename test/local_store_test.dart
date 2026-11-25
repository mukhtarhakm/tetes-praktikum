import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tetes_praktikum/data/local_store.dart';
import 'package:tetes_praktikum/data/models.dart';

void main() {
  test('diagnosis lama dan rencana berikutnya tetap terbaca', () {
    const plan = BrewPlan(
      beanId: 'bean-1',
      beanName: 'Biji uji',
      doseG: 15,
      ratio: 16,
      temperatureC: 92,
      grind: 'Sedang',
      pouringCount: 3,
    );
    final old = BrewEntry(
      id: 'brew-1',
      plan: plan,
      brewedAt: DateTime.utc(2026),
      durationS: 160,
      score: 4,
      notes: '',
    ).toMap()..['aiDiagnosis'] = 'Coba suhu lebih rendah.';
    expect(BrewEntry.fromMap(old).aiDiagnosis?.text, 'Coba suhu lebih rendah.');
    expect(BrewEntry.fromMap(old).aiDiagnosis?.nextPlan, isNull);

    final saved = BrewEntry.fromMap(old).copyWith(
      aiDiagnosis: const AiDiagnosis(
        text: 'Coba suhu lebih rendah.',
        nextPlan: BrewPlan(
          beanId: 'bean-1',
          beanName: 'Biji uji',
          doseG: 15,
          ratio: 16,
          temperatureC: 90,
          grind: 'Sedang',
          pouringCount: 3,
        ),
        note: 'Turunkan suhu dua derajat.',
      ),
    );
    final restored = BrewEntry.fromMap(saved.toMap());
    expect(restored.aiDiagnosis?.nextPlan?.temperatureC, 90);
    expect(restored.aiDiagnosis?.note, 'Turunkan suhu dua derajat.');
    expect(restored.plan.temperatureC, 92);
  });

  test('saving a brew updates stock and keeps accounts separate', () async {
    final directory = await Directory.systemTemp.createTemp('tetes_praktikum_');
    Hive.init(directory.path);
    addTearDown(() async {
      await Hive.close();
      if (directory.path.startsWith(Directory.systemTemp.path)) {
        await directory.delete(recursive: true);
      }
    });

    final first = await LocalStore.open('user-a');
    await first.saveBean(
      const Bean(
        id: 'bean-1',
        name: 'Biji uji',
        roastery: '',
        origin: '',
        stockG: 100,
        price: 0,
        currency: 'IDR',
        tastingNotes: '',
      ),
    );
    const plan = BrewPlan(
      beanId: 'bean-1',
      beanName: 'Biji uji',
      doseG: 15,
      ratio: 16,
      temperatureC: 92,
      grind: 'Sedang',
      pouringCount: 3,
    );
    await first.saveBrew(
      BrewEntry(
        id: 'brew-1',
        plan: plan,
        brewedAt: DateTime.utc(2026),
        durationS: 160,
        score: 4,
        notes: 'Segar',
        tasteTags: ['asam', 'buah'],
        customTasteTags: ['jeruk'],
        actualWaterG: [38, 100, 102, null],
        drawdownS: 45,
      ),
    );
    await first.saveDiagnosis(
      'brew-1',
      const AiDiagnosis(text: 'Coba suhu lebih rendah.'),
    );
    expect(first.beans.single.stockG, 85);
    await first.close();

    final reopened = await LocalStore.open('user-a');
    expect(reopened.brews.single.plan.beanName, 'Biji uji');
    expect(reopened.brews.single.tasteTags, ['asam', 'buah']);
    expect(reopened.brews.single.customTasteTags, ['jeruk']);
    expect(reopened.brews.single.actualWaterG, [38, 100, 102, null]);
    expect(reopened.brews.single.drawdownS, 45);
    expect(reopened.brews.single.aiDiagnosis?.text, 'Coba suhu lebih rendah.');
    expect(reopened.beans.single.stockG, 85);
    await reopened.close();

    final second = await LocalStore.open('user-b');
    expect(second.beans, isEmpty);
    expect(second.brews, isEmpty);
    await second.close();
  });
}
