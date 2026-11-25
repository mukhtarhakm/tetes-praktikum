import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:tetes_praktikum/app/app_controller.dart';
import 'package:tetes_praktikum/app/app_theme.dart';
import 'package:tetes_praktikum/data/services.dart';
import 'package:tetes_praktikum/screens/explore_screen.dart';

class _StoresController extends AppController {
  @override
  Future<StoreResult> nearbyStores() async => const StoreResult(
    [
      StorePlace(
        'TokoKopi Seduh Wangi',
        'toko_alat',
        'Maguwoharjo, Depok, Sleman',
        -7.755322,
        110.428744,
      ),
      StorePlace(
        'Darat Coffee Lab',
        'roastery',
        'Maguwoharjo, Depok, Sleman',
        -7.769539,
        110.425952,
      ),
    ],
    -7.42,
    110.4,
    null,
  );

  @override
  Future<StoreRoute> routeTo(
    double latitude,
    double longitude,
    StorePlace place,
  ) async => StoreRoute(45123.4, 3660, [
    LatLng(latitude, longitude),
    LatLng(place.latitude, place.longitude),
  ]);
}

class _NoLocationController extends _StoresController {
  @override
  Future<StoreResult> nearbyStores() async {
    final stores = await super.nearbyStores();
    return StoreResult(
      stores.places,
      null,
      null,
      'Izin lokasi ditolak. Daftar toko tetap tersedia.',
    );
  }
}

void main() {
  test('daftar tempat hanya memuat roastery dan toko alat kopi', () {
    const source = '''[
      {"name":"Roastery A","store_type":"roastery","latitude":-7.7,"longitude":110.4},
      {"name":"Toko Alat B","store_type":"toko_alat","latitude":-7.8,"longitude":110.5},
      {"name":"Toko Biji C","store_type":"toko_biji","latitude":-7.9,"longitude":110.6}
    ]''';
    final places = StoreService.parsePlaces(source);
    expect(places.map((place) => place.name), ['Roastery A', 'Toko Alat B']);
  });

  testWidgets('peta utama dan panel tempat terbaca pada layar kecil', (
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
        home: StoreScreen(controller: _StoresController()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tempat kopi'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.text('2 tempat tersedia'), findsOneWidget);
    expect(find.text('Roastery dan toko alat kopi'), findsOneWidget);
    expect(find.text('TokoKopi Seduh Wangi'), findsOneWidget);
    expect(find.text('Navigasi'), findsOneWidget);
    final visible = MapCamera.of(
      tester.element(find.byType(TileLayer)),
    ).visibleBounds;
    expect(visible.contains(const LatLng(-7.755322, 110.428744)), isTrue);
    await tester.tap(find.byIcon(Icons.location_on_rounded).last);
    await tester.pumpAndSettle();
    expect(find.text('Darat Coffee Lab'), findsOneWidget);
    expect(find.text('Roastery'), findsOneWidget);
    final camera = MapCamera.of(tester.element(find.byType(TileLayer)));
    expect(camera.center.latitude, closeTo(-7.769539, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('daftar dan navigasi tetap ada tanpa izin lokasi', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: StoreScreen(controller: _NoLocationController()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Jarak belum tersedia'), findsOneWidget);
    expect(find.textContaining('Izin lokasi ditolak'), findsOneWidget);
    expect(find.text('Navigasi'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Lihat rute'))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('rute jalan mengubah jarak dan menggambar garis pada peta', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: StoreScreen(controller: _StoresController()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Lihat rute'));
    await tester.tap(find.text('Lihat rute'));
    await tester.pumpAndSettle();
    expect(find.byType(PolylineLayer), findsOneWidget);
    expect(find.text('45.1 km lewat jalan'), findsOneWidget);
    expect(find.text('±1 jam 1 menit berkendara'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
