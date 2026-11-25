import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../data/local_store.dart';
import '../data/currencies.dart';
import '../data/models.dart';
import '../data/services.dart';

class AppController extends ChangeNotifier {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  final _fx = FxService();
  final _stores = StoreService();
  final _routes = RouteService();
  final notifications = NotificationService();
  final _uuid = const Uuid();
  SupabaseClient? _client;
  StreamSubscription<AuthState>? _authSubscription;
  LocalStore? _local;
  int _loadGeneration = 0;

  bool loading = true;
  String? error;
  String? userId;
  String? email;

  bool get configured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
  List<Bean> get beans => _local?.beans ?? const [];
  List<BrewEntry> get brews => _local?.brews ?? const [];
  Uint8List? get profilePhoto => _local?.profilePhoto;

  Future<void> initialize() async {
    try {
      await Hive.initFlutter();
      await notifications.initialize();
      if (!configured) {
        error = 'Akun belum terhubung. Hubungi pengelola aplikasi.';
        return;
      }
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabasePublishableKey,
      );
      _client = Supabase.instance.client;
      await _loadUser(
        _client!.auth.currentUser?.id,
        _client!.auth.currentUser?.email,
      );
      _authSubscription = _client!.auth.onAuthStateChange.listen((event) {
        unawaited(_loadUser(event.session?.user.id, event.session?.user.email));
      });
      if (_client!.auth.currentUser?.id != userId) {
        await _loadUser(
          _client!.auth.currentUser?.id,
          _client!.auth.currentUser?.email,
        );
      }
    } catch (_) {
      error = 'Aplikasi belum dapat dibuka. Coba lagi nanti.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadUser(String? nextId, String? nextEmail) async {
    if (nextId == userId && (loading || nextId == null || _local != null)) {
      return;
    }
    final generation = ++_loadGeneration;
    loading = true;
    final old = _local;
    _local = null;
    userId = nextId;
    email = nextEmail;
    notifyListeners();
    await old?.close();
    try {
      final next = nextId == null ? null : await LocalStore.open(nextId);
      if (generation != _loadGeneration) {
        await next?.close();
        return;
      }
      _local = next;
      userId = nextId;
      email = nextEmail;
      error = null;
    } catch (_) {
      userId = null;
      email = null;
      error = 'Data lokal belum bisa dibuka. Coba buka ulang aplikasi.';
    } finally {
      if (generation == _loadGeneration) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> register(String email, String password) async {
    final response = await _client!.auth.signUp(
      email: email.trim(),
      password: password,
    );
    return response.session != null;
  }

  Future<void> login(String email, String password) async {
    await _client!.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> logout() async {
    await _client!.auth.signOut();
    await _loadUser(null, null);
  }

  Future<void> saveBean({
    String? id,
    required String name,
    required String roastery,
    required String origin,
    required double stockG,
    required double price,
    required String currency,
    required String tastingNotes,
    required String? species,
    required String? beanType,
    required int? arabicaPercent,
    required bool isSelfRoasted,
    required String? process,
    required String? processCustom,
    required String? roastLevel,
    required String? roastDate,
    required double? packSizeG,
    required double? packPrice,
    required List<String> tastingTags,
  }) async {
    if (name.trim().isEmpty ||
        name.trim().length > 60 ||
        roastery.length > 60 ||
        origin.length > 100 ||
        tastingNotes.length > 300 ||
        stockG < 0 ||
        !stockG.isFinite ||
        price < 0 ||
        !price.isFinite ||
        !currencyNames.containsKey(currency) ||
        !const {'Arabika', 'Robusta', 'Campuran'}.contains(species) ||
        (beanType != null &&
            !const {'Single origin', 'Blend'}.contains(beanType)) ||
        (species == 'Campuran' &&
            (arabicaPercent == null ||
                arabicaPercent < 0 ||
                arabicaPercent > 100)) ||
        (process != null &&
            !const {
              'Washed',
              'Natural',
              'Honey',
              'Lainnya',
            }.contains(process)) ||
        (process == 'Lainnya' &&
            (processCustom == null ||
                processCustom.trim().isEmpty ||
                processCustom.length > 40)) ||
        (roastLevel != null &&
            !const {'Light', 'Medium', 'Dark'}.contains(roastLevel)) ||
        (packSizeG != null && (!packSizeG.isFinite || packSizeG <= 0)) ||
        (packPrice != null &&
            (!packPrice.isFinite || packPrice <= 0 || packSizeG == null)) ||
        tastingTags.length > 10 ||
        tastingTags.toSet().length != tastingTags.length ||
        tastingTags.any((tag) => tag.isEmpty || tag.length > 30)) {
      throw const FormatException(
        'Periksa data biji, kemasan, harga, dan tag rasa.',
      );
    }
    final bean = Bean(
      id: id ?? _uuid.v4(),
      name: name.trim(),
      roastery: isSelfRoasted ? 'Roasting sendiri' : roastery.trim(),
      origin: origin.trim(),
      stockG: stockG,
      price: price,
      currency: currency,
      tastingNotes: tastingNotes.trim(),
      species: species,
      beanType: beanType,
      arabicaPercent: species == 'Campuran' ? arabicaPercent : null,
      isSelfRoasted: isSelfRoasted,
      process: process,
      processCustom: process == 'Lainnya' ? processCustom?.trim() : null,
      roastLevel: roastLevel,
      roastDate: roastDate,
      packSizeG: packSizeG,
      packPrice: packPrice,
      tastingTags: List.unmodifiable(tastingTags),
    );
    await _local!.saveBean(bean);
    notifyListeners();
  }

  Future<void> deleteBean(String id) async {
    if (brews.any((brew) => brew.plan.beanId == id)) {
      throw const FormatException(
        'Biji yang sudah diseduh tidak dapat dihapus.',
      );
    }
    await _local!.deleteBean(id);
    notifyListeners();
  }

  Future<void> saveProfilePhoto(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.lengthInBytes > 2 * 1024 * 1024) {
      throw const FormatException('Foto terlalu besar. Pilih foto lain.');
    }
    await _local!.saveProfilePhoto(bytes);
    notifyListeners();
  }

  Future<BrewEntry> saveBrew(
    BrewPlan plan,
    int durationS,
    int score,
    String notes, {
    required List<String> tasteTags,
    List<String> customTasteTags = const [],
    required List<double?> cumulativeWaterG,
    int? drawdownS,
  }) async {
    final custom = customTasteTags
        .map((tag) => tag.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase())
        .toList();
    if (score < 1 ||
        score > 5 ||
        tasteTags.isEmpty ||
        tasteTags.toSet().length != tasteTags.length ||
        tasteTags.any((tag) => !TasteTags.builtIn.contains(tag)) ||
        custom.length > 3 ||
        custom.toSet().length != custom.length ||
        custom.any(
          (tag) =>
              tag.isEmpty ||
              tag.runes.length > 20 ||
              TasteTags.builtIn.contains(tag) ||
              !RegExp(r'^[\p{L}\p{N} -]+$', unicode: true).hasMatch(tag),
        ) ||
        notes.length > 300 ||
        durationS < 0 ||
        (drawdownS != null && drawdownS < 0)) {
      throw const FormatException(
        'Periksa skor, tag rasa, catatan, dan waktu.',
      );
    }
    final actualWaterG = BrewEntry.actualPours(
      cumulativeWaterG,
      plan.stages.length,
    );
    final entry = BrewEntry(
      id: _uuid.v4(),
      plan: plan,
      brewedAt: DateTime.now().toUtc(),
      durationS: durationS,
      score: score,
      notes: notes.trim(),
      tasteTags: List.unmodifiable(tasteTags),
      customTasteTags: List.unmodifiable(custom),
      actualWaterG: List.unmodifiable(actualWaterG),
      drawdownS: drawdownS,
    );
    await _local!.saveBrew(entry);
    notifyListeners();
    return entry;
  }

  Future<FxQuote> rate(String currency) async {
    try {
      final quote = await _fx.fetch(currency);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fx_$currency', '${quote.rate}|${quote.date}');
      return quote;
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      final parts = prefs.getString('fx_$currency')?.split('|');
      if (parts?.length == 2) {
        final rate = double.tryParse(parts![0]);
        if (rate != null && rate > 0) {
          return FxQuote(currency, rate, parts[1], cached: true);
        }
      }
      rethrow;
    }
  }

  Future<StoreResult> nearbyStores() => _stores.nearby();

  Future<StoreRoute> routeTo(
    double latitude,
    double longitude,
    StorePlace place,
  ) => _routes.fetch(latitude, longitude, place);

  Future<AiRecommendation> recommend(
    Bean bean,
    AiPreferences preferences,
  ) => AiService(_client!).recommend(
    bean,
    [
      ...brews.where((item) => item.plan.beanId == bean.id && item.score == 5),
      ...brews.where((item) => item.plan.beanId == bean.id && item.score == 4),
    ].take(8).toList(),
    preferences,
  );

  Future<AiDiagnosis> diagnose(BrewEntry brew) async {
    final result = await AiService(_client!).diagnose(
      brew,
      brews
          .where(
            (item) =>
                item.id != brew.id &&
                item.plan.beanId == brew.plan.beanId &&
                item.score == 5,
          )
          .take(3)
          .toList(),
    );
    await _local!.saveDiagnosis(brew.id, result);
    notifyListeners();
    return result;
  }

  Future<void> scheduleReminder(BrewReminder reminder) =>
      notifications.scheduleReminder(userId!, reminder);
  Future<BrewReminder?> savedReminder() => notifications.savedReminder(userId!);
  Future<void> cancelReminder() => notifications.cancelReminder(userId!);

  @override
  void dispose() {
    _authSubscription?.cancel();
    unawaited(_local?.close());
    super.dispose();
  }
}
