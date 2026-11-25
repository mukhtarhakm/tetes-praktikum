import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'currencies.dart';
import 'models.dart';

class FxQuote {
  const FxQuote(this.currency, this.rate, this.date, {this.cached = false});
  final String currency;
  final double rate;
  final String date;
  final bool cached;
}

class FxService {
  Future<FxQuote> fetch(String currency) async {
    if (currency == 'IDR') {
      return FxQuote(
        currency,
        1,
        DateTime.now().toIso8601String().substring(0, 10),
      );
    }
    if (!currencyNames.containsKey(currency)) {
      throw const FormatException('Mata uang tidak didukung.');
    }
    final uri = Uri.https('api.frankfurter.dev', '/v1/latest', {
      'base': currency,
      'symbols': 'IDR',
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw const FormatException('Layanan kurs belum tersedia.');
    }
    return parse(response.body, currency);
  }

  static FxQuote parse(String source, String currency) {
    final body = jsonDecode(source);
    if (body is! Map || body['rates'] is! Map || body['date'] is! String) {
      throw const FormatException('Data kurs tidak valid.');
    }
    final rate = (body['rates'] as Map)['IDR'];
    if (rate is! num ||
        !rate.isFinite ||
        rate <= 0 ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(body['date'] as String)) {
      throw const FormatException('Kurs rupiah tidak tersedia.');
    }
    return FxQuote(currency, rate.toDouble(), body['date'] as String);
  }
}

class StorePlace {
  const StorePlace(
    this.name,
    this.type,
    this.address,
    this.latitude,
    this.longitude,
  );
  final String name;
  final String type;
  final String address;
  final double latitude;
  final double longitude;
}

class StoreResult {
  const StoreResult(this.places, this.latitude, this.longitude, this.message);
  final List<StorePlace> places;
  final double? latitude;
  final double? longitude;
  final String? message;

  double? distanceTo(StorePlace place) => latitude == null || longitude == null
      ? null
      : Geolocator.distanceBetween(
          latitude!,
          longitude!,
          place.latitude,
          place.longitude,
        );
}

class StoreService {
  Future<StoreResult> nearby() async {
    final source = await rootBundle.loadString('assets/data/stores.json');
    final places = parsePlaces(source);
    if (!await Geolocator.isLocationServiceEnabled()) {
      return StoreResult(
        places,
        null,
        null,
        'GPS belum aktif. Daftar toko tetap tersedia.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return StoreResult(
        places,
        null,
        null,
        'Izin lokasi ditolak. Daftar toko tetap tersedia.',
      );
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      places.sort(
        (a, b) =>
            Geolocator.distanceBetween(
              position.latitude,
              position.longitude,
              a.latitude,
              a.longitude,
            ).compareTo(
              Geolocator.distanceBetween(
                position.latitude,
                position.longitude,
                b.latitude,
                b.longitude,
              ),
            ),
      );
      return StoreResult(places, position.latitude, position.longitude, null);
    } catch (_) {
      return StoreResult(
        places,
        null,
        null,
        'Lokasi belum bisa dibaca. Daftar toko tetap tersedia.',
      );
    }
  }

  static List<StorePlace> parsePlaces(String source) {
    final decoded = jsonDecode(source) as List;
    final places = decoded
        .where((item) {
          final type = (item as Map)['store_type'];
          return type == 'roastery' || type == 'toko_alat';
        })
        .map((item) {
          final value = item as Map;
          return StorePlace(
            value['name'] as String,
            value['store_type'] as String,
            value['address'] as String? ?? '',
            (value['latitude'] as num).toDouble(),
            (value['longitude'] as num).toDouble(),
          );
        })
        .toList();
    return places;
  }
}

class StoreRoute {
  const StoreRoute(this.distanceM, this.durationS, this.points);
  final double distanceM;
  final double durationS;
  final List<LatLng> points;
}

class RouteService {
  DateTime? _lastRequestAt;

  Future<StoreRoute> fetch(
    double latitude,
    double longitude,
    StorePlace place,
  ) async {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        !place.latitude.isFinite ||
        !place.longitude.isFinite ||
        latitude.abs() > 90 ||
        place.latitude.abs() > 90 ||
        longitude.abs() > 180 ||
        place.longitude.abs() > 180) {
      throw const FormatException('Koordinat lokasi tidak valid.');
    }
    final last = _lastRequestAt;
    if (last != null) {
      final wait = const Duration(seconds: 1) - DateTime.now().difference(last);
      if (wait > Duration.zero) await Future.delayed(wait);
    }
    _lastRequestAt = DateTime.now();
    // shortcut: server demo untuk TA terbatas; pindah ke layanan terkelola bila pemakaian meluas.
    final uri = Uri.https(
      'router.project-osrm.org',
      '/route/v1/driving/$longitude,$latitude;${place.longitude},${place.latitude}',
      {'overview': 'full', 'geometries': 'geojson'},
    );
    final response = await http
        .get(
          uri,
          headers: {
            'User-Agent':
                'TetesPraktikum/1.0 (com.raismukhtar.tetes_praktikum)',
          },
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw const FormatException('Rute belum tersedia.');
    }
    return parse(response.body);
  }

  static StoreRoute parse(String source) {
    final body = jsonDecode(source);
    if (body is! Map || body['code'] != 'Ok' || body['routes'] is! List) {
      throw const FormatException('Data rute tidak valid.');
    }
    final routes = body['routes'] as List;
    if (routes.isEmpty || routes.first is! Map) {
      throw const FormatException('Rute tidak ditemukan.');
    }
    final route = routes.first as Map;
    final distance = route['distance'];
    final duration = route['duration'];
    final geometry = route['geometry'];
    final coordinates = geometry is Map ? geometry['coordinates'] : null;
    if (distance is! num ||
        duration is! num ||
        !distance.isFinite ||
        !duration.isFinite ||
        distance < 0 ||
        duration < 0 ||
        coordinates is! List ||
        coordinates.length < 2 ||
        coordinates.length > 10000) {
      throw const FormatException('Data rute tidak valid.');
    }
    final points = <LatLng>[];
    for (final coordinate in coordinates) {
      if (coordinate is! List ||
          coordinate.length < 2 ||
          coordinate[0] is! num ||
          coordinate[1] is! num) {
        throw const FormatException('Titik rute tidak valid.');
      }
      final lng = (coordinate[0] as num).toDouble();
      final lat = (coordinate[1] as num).toDouble();
      if (!lng.isFinite || !lat.isFinite || lng.abs() > 180 || lat.abs() > 90) {
        throw const FormatException('Titik rute tidak valid.');
      }
      points.add(LatLng(lat, lng));
    }
    return StoreRoute(
      distance.toDouble(),
      duration.toDouble(),
      List.unmodifiable(points),
    );
  }
}

enum ReminderRepeat { once, daily, weekly }

class BrewReminder {
  const BrewReminder(this.when, this.repeat);

  final DateTime when;
  final ReminderRepeat repeat;

  static DateTime nextAt(DateTime now, int hour, int minute, {int? weekday}) {
    final days = weekday == null ? 0 : (weekday - now.weekday + 7) % 7;
    var next = DateTime(now.year, now.month, now.day + days, hour, minute);
    if (!next.isAfter(now)) {
      next = DateTime(
        now.year,
        now.month,
        now.day + days + (weekday == null ? 1 : 7),
        hour,
        minute,
      );
    }
    return next;
  }
}

class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'brew_reminders',
      'Pengingat seduh',
      channelDescription: 'Pengingat seduh V60',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }

  Future<bool> requestPermission() async =>
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission() ??
      false;

  Future<void> scheduleReminder(String userId, BrewReminder reminder) async {
    if (!reminder.when.isAfter(DateTime.now())) {
      throw const FormatException('Pilih waktu yang akan datang.');
    }
    final granted = await requestPermission();
    if (!granted) {
      throw const FormatException('Izin notifikasi belum diberikan.');
    }
    await _plugin.zonedSchedule(
      id: 2,
      title: 'Waktunya menyeduh',
      body: 'Siapkan biji favoritmu dan mulai seduh V60.',
      scheduledDate: tz.TZDateTime.from(reminder.when.toUtc(), tz.UTC),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // shortcut: jam berulang mengikuti zona waktu saat diatur; pakai zona perangkat jika harus mengikuti perjalanan.
      matchDateTimeComponents: switch (reminder.repeat) {
        ReminderRepeat.once => null,
        ReminderRepeat.daily => DateTimeComponents.time,
        ReminderRepeat.weekly => DateTimeComponents.dayOfWeekAndTime,
      },
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'reminder_$userId',
      '${reminder.repeat.name}|${reminder.when.toIso8601String()}',
    );
  }

  Future<BrewReminder?> savedReminder(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('reminder_$userId');
    if (value == null) return null;
    final parts = value.split('|');
    if (parts.length == 1) {
      final oldWhen = DateTime.tryParse(parts.single);
      return oldWhen == null
          ? null
          : BrewReminder(oldWhen, ReminderRepeat.once);
    }
    if (parts.length != 2) return null;
    final when = DateTime.tryParse(parts[1]);
    for (final repeat in ReminderRepeat.values) {
      if (repeat.name == parts[0] && when != null) {
        return BrewReminder(when, repeat);
      }
    }
    return null;
  }

  Future<void> cancelReminder(String userId) async {
    await _plugin.cancel(id: 2);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('reminder_$userId');
  }
}

class AiRecommendation {
  const AiRecommendation({
    required this.doseG,
    required this.ratio,
    required this.temperatureC,
    required this.grind,
    required this.stages,
    required this.note,
  });
  final double doseG;
  final double ratio;
  final int temperatureC;
  final String grind;
  final List<BrewStage> stages;
  final String note;

  int get pouringCount => stages.length;

  static AiRecommendation fromMap(Map data) {
    final dose = (data['dose_g'] as num?)?.toDouble();
    final ratio = (data['ratio'] as num?)?.toDouble();
    final temperature = data['temperature_c'];
    final grind = data['grind'];
    final pouringCount = data['pouring_count'];
    final stagesData = data['stages'];
    final note = data['note'];
    if (dose == null ||
        !dose.isFinite ||
        dose < 5 ||
        dose > 40 ||
        ratio == null ||
        !ratio.isFinite ||
        ratio < 10 ||
        ratio > 20 ||
        temperature is! int ||
        temperature < 80 ||
        temperature > 100 ||
        !const {'Halus', 'Sedang', 'Kasar'}.contains(grind) ||
        stagesData is! List ||
        stagesData.isEmpty ||
        stagesData.length > 5 ||
        pouringCount is! int ||
        pouringCount != stagesData.length ||
        note is! String ||
        note.trim().isEmpty ||
        note.length > 300) {
      throw const FormatException('Saran AI belum tersedia.');
    }
    final stages = <BrewStage>[];
    for (var i = 0; i < stagesData.length; i++) {
      final stage = stagesData[i];
      if (stage is! Map ||
          stage['duration_s'] is! int ||
          (stage['duration_s'] as int) < 5 ||
          (stage['duration_s'] as int) > 120 ||
          stage['water_g'] is! num ||
          !(stage['water_g'] as num).isFinite ||
          (stage['water_g'] as num) <= 0) {
        throw const FormatException('Urutan tuang dari AI tidak valid.');
      }
      stages.add(
        BrewStage(
          i == 0 && stagesData.length > 1
              ? 'Pouring 1 · Bloom'
              : 'Pouring ${i + 1}',
          stage['duration_s'] as int,
          (stage['water_g'] as num).toDouble(),
        ),
      );
    }
    final total = dose * ratio;
    final beforeLast = stages
        .take(stages.length - 1)
        .fold<double>(0, (sum, stage) => sum + stage.waterG);
    final lastWater = total - beforeLast;
    if (lastWater <= 0 || (stages.last.waterG - lastWater).abs() > 1) {
      throw const FormatException('Total air dari AI tidak sesuai rasio.');
    }
    stages[stages.length - 1] = BrewStage(
      stages.last.name,
      stages.last.durationS,
      lastWater,
    );
    return AiRecommendation(
      doseG: dose,
      ratio: ratio,
      temperatureC: temperature,
      grind: grind as String,
      stages: List.unmodifiable(stages),
      note: note.trim(),
    );
  }
}

class AiPreferences {
  const AiPreferences({
    this.goal = '',
    this.doseG,
    this.ratio,
    this.temperatureC,
    this.grind,
    this.pouringCount,
  });

  final String goal;
  final double? doseG;
  final double? ratio;
  final int? temperatureC;
  final String? grind;
  final int? pouringCount;

  Map<String, dynamic> get constraints => {
    if (doseG != null) 'dose_g': doseG,
    if (ratio != null) 'ratio': ratio,
    if (temperatureC != null) 'temperature_c': temperatureC,
    if (grind != null) 'grind': grind,
    if (pouringCount != null) 'pouring_count': pouringCount,
  };
}

class AiService {
  AiService(this.client);
  final SupabaseClient client;

  Map<String, dynamic> _brewData(BrewEntry brew) => {
    'dose_g': brew.plan.doseG,
    'ratio': brew.plan.ratio,
    'temperature_c': brew.plan.temperatureC,
    'grind': brew.plan.grind,
    'pouring_count': brew.plan.pouringCount,
    'stages': [
      for (final stage in brew.plan.customStages ?? const <BrewStage>[])
        {'duration_s': stage.durationS, 'water_g': stage.waterG},
    ],
    'score': brew.score,
    'taste_tags': [...brew.tasteTags, ...brew.customTasteTags],
    'notes': brew.notes,
    'duration_s': brew.durationS,
    'actual_water_g': brew.actualWaterG,
    'drawdown_s': brew.drawdownS,
  };

  Future<AiRecommendation> recommend(
    Bean bean,
    List<BrewEntry> history,
    AiPreferences preferences,
  ) async {
    final response = await client.functions.invoke(
      'brew-ai',
      body: {
        'type': 'recommend',
        'bean': {
          'name': bean.name,
          'origin': bean.origin,
          'tasting_notes': bean.tastingNotes,
          'tasting_tags': bean.tastingTags,
          'process': bean.process,
          'roast_level': bean.roastLevel,
          'stock_g': bean.stockG,
        },
        'history': history.take(8).map(_brewData).toList(),
        'goal': preferences.goal.trim(),
        'constraints': preferences.constraints,
      },
    );
    final data = response.data;
    if (data is! Map) {
      throw const FormatException('Saran AI belum tersedia.');
    }
    final suggestion = AiRecommendation.fromMap(data);
    if (suggestion.doseG > bean.stockG ||
        (preferences.doseG != null &&
            (suggestion.doseG - preferences.doseG!).abs() > 0.01) ||
        (preferences.ratio != null &&
            (suggestion.ratio - preferences.ratio!).abs() > 0.01) ||
        (preferences.temperatureC != null &&
            suggestion.temperatureC != preferences.temperatureC) ||
        (preferences.grind != null && suggestion.grind != preferences.grind) ||
        (preferences.pouringCount != null &&
            suggestion.pouringCount != preferences.pouringCount)) {
      throw const FormatException(
        'Saran AI tidak sesuai pilihanmu. Coba lagi.',
      );
    }
    return suggestion;
  }

  Future<AiDiagnosis> diagnose(
    BrewEntry brew,
    List<BrewEntry> goodHistory,
  ) async {
    final response = await client.functions.invoke(
      'brew-ai',
      body: {
        'type': 'diagnose',
        'brew': _brewData(brew),
        'good_history': goodHistory.take(3).map(_brewData).toList(),
      },
    );
    final data = response.data;
    if (data is! Map ||
        data['diagnosis'] is! String ||
        (data['diagnosis'] as String).trim().isEmpty ||
        (data['diagnosis'] as String).length > 400) {
      throw const FormatException('Diagnosa AI belum tersedia.');
    }
    final next = data['next_plan'];
    final suggestion = next is Map ? AiRecommendation.fromMap(next) : null;
    return AiDiagnosis(
      text: (data['diagnosis'] as String).trim(),
      nextPlan: suggestion == null
          ? null
          : BrewPlan(
              beanId: brew.plan.beanId,
              beanName: brew.plan.beanName,
              doseG: suggestion.doseG,
              ratio: suggestion.ratio,
              temperatureC: suggestion.temperatureC,
              grind: suggestion.grind,
              pouringCount: suggestion.pouringCount,
              customStages: suggestion.stages,
            ),
      note: suggestion?.note ?? '',
    );
  }
}
