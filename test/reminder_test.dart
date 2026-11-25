import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tetes_praktikum/data/services.dart';

void main() {
  test('pengingat harian dan mingguan mencari waktu berikutnya', () {
    final now = DateTime(2026, 11, 17, 10, 30);
    expect(BrewReminder.nextAt(now, 10, 0), DateTime(2026, 11, 18, 10));
    expect(
      BrewReminder.nextAt(now, 10, 0, weekday: DateTime.tuesday),
      DateTime(2026, 11, 24, 10),
    );
    expect(
      BrewReminder.nextAt(now, 11, 0, weekday: DateTime.tuesday),
      DateTime(2026, 11, 17, 11),
    );
  });

  test('pengingat lama dan pola baru terbaca', () async {
    SharedPreferences.setMockInitialValues({
      'reminder_old': '2026-11-17T22:50:00.000',
      'reminder_new': 'weekly|2026-11-23T22:50:00.000',
    });
    final service = NotificationService();
    expect((await service.savedReminder('old'))?.repeat, ReminderRepeat.once);
    final weekly = await service.savedReminder('new');
    expect(weekly?.repeat, ReminderRepeat.weekly);
    expect(weekly?.when.weekday, DateTime.monday);
  });
}
