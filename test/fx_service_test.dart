import 'package:flutter_test/flutter_test.dart';
import 'package:tetes_praktikum/data/services.dart';

void main() {
  test('parses a rupiah quote from the API response', () {
    const source =
        '{"amount":1,"base":"USD","date":"2026-10-16","rates":{"IDR":18031}}';
    final quote = FxService.parse(source, 'USD');
    expect(quote.rate, 18031);
    expect(quote.date, '2026-10-16');
  });

  test('rejects a response without an IDR rate', () {
    expect(
      () => FxService.parse('{"date":"2026-10-16","rates":{}}', 'USD'),
      throwsFormatException,
    );
  });
}
