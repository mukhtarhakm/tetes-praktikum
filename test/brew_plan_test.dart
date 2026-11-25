import 'package:flutter_test/flutter_test.dart';
import 'package:tetes_praktikum/data/models.dart';

void main() {
  test('legacy water targets remain readable', () {
    for (var pouringCount = 1; pouringCount <= 5; pouringCount++) {
      final plan = BrewPlan(
        beanId: 'bean',
        beanName: 'Biji',
        doseG: 15,
        ratio: 16,
        temperatureC: 92,
        grind: 'Sedang',
        pouringCount: pouringCount,
      );
      final targets = plan.stages.map((stage) => stage.waterG).toList();
      expect(targets.last, 240);
      for (var i = 1; i < targets.length; i++) {
        expect(targets[i], greaterThanOrEqualTo(targets[i - 1]));
      }
    }
  });

  test(
    'new pouring stages have durations and per-stage water that survive storage',
    () {
      final stages = BrewPlan.defaultPourStages(15, 15, 3);
      expect(stages.map((stage) => stage.name), [
        'Pouring 1 · Bloom',
        'Pouring 2',
        'Pouring 3',
      ]);
      expect(stages.map((stage) => stage.durationS), [40, 30, 30]);
      expect(stages.map((stage) => stage.waterG), [45, 90, 90]);

      final plan = BrewPlan(
        beanId: 'bean',
        beanName: 'Biji',
        doseG: 15,
        ratio: 15,
        temperatureC: 92,
        grind: 'Sedang',
        pouringCount: 3,
        customStages: stages,
      );
      final restored = BrewPlan.fromMap(plan.toMap());
      expect(restored.stages.map((stage) => stage.waterG), [45, 90, 90]);
    },
  );
}
