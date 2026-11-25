import 'package:flutter_test/flutter_test.dart';
import 'package:tetes_praktikum/data/models.dart';

void main() {
  test('old beans load and new fields survive stock changes', () {
    final old = Bean.fromMap({'id': 'old', 'name': 'Biji lama', 'stockG': 250});
    expect(old.species, isNull);
    expect(old.tastingTags, isEmpty);

    const bean = Bean(
      id: 'new',
      name: 'Biji baru',
      roastery: 'Roasting sendiri',
      origin: 'Gayo',
      stockG: 250,
      price: 200000,
      currency: 'IDR',
      tastingNotes: 'Jeruk',
      species: 'Arabika',
      process: 'Washed',
      roastLevel: 'Light',
      packSizeG: 250,
      packPrice: 50000,
      tastingTags: ['asam', 'buah'],
    );
    final restored = Bean.fromMap(bean.copyWith(stockG: 235).toMap());
    expect(restored.stockG, 235);
    expect(restored.packPrice, 50000);
    expect(restored.tastingTags, ['asam', 'buah']);
    expect(restored.species, 'Arabika');
  });
}
