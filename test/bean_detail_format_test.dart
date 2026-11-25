import 'package:flutter_test/flutter_test.dart';
import 'package:tetes_praktikum/app/app_controller.dart';
import 'package:tetes_praktikum/screens/beans_screen.dart';

void main() {
  test('harga di detail beans mudah dibaca untuk rupiah dan kurs', () {
    final screen = BeanDetailScreen(
      controller: AppController(),
      beanId: 'bean',
    );
    expect(screen.priceText(80000, 'IDR'), 'Rp80.000');
    expect(screen.priceText(12500, 'USD'), 'USD 12.500');
  });
}
