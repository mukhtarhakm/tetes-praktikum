import 'package:flutter_test/flutter_test.dart';
import 'package:tetes_praktikum/data/services.dart';

void main() {
  final response = {
    'dose_g': 15,
    'ratio': 16,
    'temperature_c': 92,
    'grind': 'Sedang',
    'pouring_count': 3,
    'stages': [
      {'duration_s': 40, 'water_g': 45},
      {'duration_s': 30, 'water_g': 95},
      {'duration_s': 30, 'water_g': 100},
    ],
    'note': 'Coba untuk rasa lebih manis.',
  };

  test('AI memberi rencana tuang lengkap dengan total air tepat', () {
    final value = AiRecommendation.fromMap(response);
    expect(value.pouringCount, 3);
    expect(value.stages.first.name, contains('Bloom'));
    expect(
      value.stages.fold<double>(0, (sum, stage) => sum + stage.waterG),
      240,
    );
  });

  test('rencana AI dengan air tidak sesuai rasio ditolak', () {
    final invalid = {
      ...response,
      'stages': [
        {'duration_s': 40, 'water_g': 45},
        {'duration_s': 30, 'water_g': 95},
        {'duration_s': 30, 'water_g': 120},
      ],
    };
    expect(() => AiRecommendation.fromMap(invalid), throwsFormatException);
  });
}
