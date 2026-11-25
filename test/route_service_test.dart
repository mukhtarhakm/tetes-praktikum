import 'package:flutter_test/flutter_test.dart';
import 'package:tetes_praktikum/data/services.dart';

void main() {
  test('rute OSRM memuat jarak, durasi, dan titik jalan', () {
    const source = '''{
      "code":"Ok",
      "routes":[{
        "distance":45123.4,
        "duration":3660,
        "geometry":{"type":"LineString","coordinates":[[110.4,-7.42],[110.42,-7.6],[110.428744,-7.755322]]}
      }]
    }''';
    final route = RouteService.parse(source);
    expect(route.distanceM, 45123.4);
    expect(route.durationS, 3660);
    expect(route.points.first.latitude, -7.42);
    expect(route.points.last.longitude, 110.428744);
  });

  test('rute kosong atau koordinat rusak ditolak', () {
    expect(
      () => RouteService.parse('{"code":"NoRoute","routes":[]}'),
      throwsFormatException,
    );
    expect(
      () => RouteService.parse(
        '{"code":"Ok","routes":[{"distance":100,"duration":60,"geometry":{"coordinates":[[110,-7],[200,-8]]}}]}',
      ),
      throwsFormatException,
    );
  });
}
