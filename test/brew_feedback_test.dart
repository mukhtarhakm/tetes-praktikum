import 'package:flutter_test/flutter_test.dart';
import 'package:tetes_praktikum/data/models.dart';

void main() {
  test('cumulative scale readings become per-pour water', () {
    expect(BrewEntry.actualPours([45, 135, 225], 3), [45, 90, 90]);
    expect(
      () => BrewEntry.actualPours([45, 40, 225], 3),
      throwsFormatException,
    );
    expect(() => BrewEntry.actualPours([45], 3), throwsFormatException);
  });

  test('old journal entries load with empty feedback', () {
    final old = BrewEntry.fromMap({
      'id': 'old',
      'plan': const BrewPlan(
        beanId: 'bean',
        beanName: 'Biji',
        doseG: 15,
        ratio: 15,
        temperatureC: 92,
        grind: 'Sedang',
        pouringCount: 3,
      ).toMap(),
      'brewedAt': '2026-11-15T00:00:00Z',
      'durationS': 160,
      'score': 4,
    });
    expect(old.tasteTags, isEmpty);
    expect(old.actualWaterG, isEmpty);
    expect(old.drawdownS, isNull);
  });
}
