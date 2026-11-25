import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tetes_praktikum/app/app_controller.dart';
import 'package:tetes_praktikum/app/app_theme.dart';
import 'package:tetes_praktikum/data/local_store.dart';
import 'package:tetes_praktikum/data/services.dart';
import 'package:tetes_praktikum/screens/profile_screen.dart';

class _ProfileController extends AppController {
  _ProfileController() {
    email = 'raismkhtr19@gmail.com';
  }

  @override
  Future<BrewReminder?> savedReminder() async => null;

  BrewReminder? scheduled;

  @override
  Future<void> scheduleReminder(BrewReminder reminder) async {
    scheduled = reminder;
  }

  @override
  Future<void> cancelReminder() async {
    scheduled = null;
  }
}

void main() {
  test('foto profil tersimpan untuk akun yang benar', () async {
    final directory = await Directory.systemTemp.createTemp('tetes_profile_');
    Hive.init(directory.path);
    addTearDown(() async {
      await Hive.close();
      await directory.delete(recursive: true);
    });

    final first = await LocalStore.open('first');
    final photo = Uint8List.fromList([1, 2, 3]);
    await first.saveProfilePhoto(photo);
    await first.close();

    final reopened = await LocalStore.open('first');
    expect(reopened.profilePhoto, orderedEquals(photo));
    final other = await LocalStore.open('other');
    expect(other.profilePhoto, isNull);
  });

  testWidgets('profil ringkas tetap terbaca pada layar sempit', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = _ProfileController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          appBar: AppBar(title: const Text('Profil')),
          body: ProfileScreen(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ganti foto'), findsOneWidget);
    expect(find.text('0 beans'), findsOneWidget);
    expect(find.text('0 seduhan'), findsOneWidget);
    expect(find.text('Belum dijadwalkan'), findsOneWidget);
    expect(find.text('Keluar akun'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pengingat dapat dipilih harian atau mingguan', (tester) async {
    final controller = _ProfileController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: ProfileScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Belum dijadwalkan'));
    await tester.pumpAndSettle();
    expect(find.text('Sekali'), findsOneWidget);
    expect(find.text('Setiap hari'), findsOneWidget);
    expect(find.text('Setiap minggu'), findsOneWidget);

    await tester.tap(find.text('Setiap hari'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(controller.scheduled?.repeat, ReminderRepeat.daily);
    expect(find.textContaining('Setiap hari ·'), findsOneWidget);

    await tester.tap(find.textContaining('Setiap hari ·'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Setiap minggu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Senin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(controller.scheduled?.repeat, ReminderRepeat.weekly);
    expect(controller.scheduled?.when.weekday, DateTime.monday);
    expect(find.textContaining('Setiap Senin ·'), findsOneWidget);
    await tester.tap(find.text('Matikan pengingat'));
    await tester.pumpAndSettle();
    expect(controller.scheduled, isNull);
    expect(find.text('Belum dijadwalkan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
