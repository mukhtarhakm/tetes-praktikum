import 'dart:typed_data';

import 'package:hive/hive.dart';

import 'models.dart';

class LocalStore {
  LocalStore._(this._box, this.beans, this.brews, this.profilePhoto);

  final Box<dynamic> _box;
  List<Bean> beans;
  List<BrewEntry> brews;
  Uint8List? profilePhoto;
  Future<void> _pending = Future.value();

  static Future<LocalStore> open(String userId) async {
    final box = await Hive.openBox<dynamic>('journal_$userId');
    final data = box.get('data') as Map<dynamic, dynamic>?;
    return LocalStore._(
      box,
      (data?['beans'] as List? ?? [])
          .map((item) => Bean.fromMap(item as Map))
          .toList(),
      (data?['brews'] as List? ?? [])
          .map((item) => BrewEntry.fromMap(item as Map))
          .toList(),
      box.get('profile_photo') as Uint8List?,
    );
  }

  Future<void> saveProfilePhoto(Uint8List bytes) => _serial(() async {
    await _box.put('profile_photo', bytes);
    profilePhoto = bytes;
  });

  Future<void> saveBean(Bean bean) => _serial(() async {
    final next = [...beans];
    final index = next.indexWhere((item) => item.id == bean.id);
    if (index < 0) {
      next.add(bean);
    } else {
      next[index] = bean;
    }
    await _write(next, brews);
  });

  Future<void> deleteBean(String id) => _serial(() async {
    await _write(beans.where((bean) => bean.id != id).toList(), brews);
  });

  Future<void> saveBrew(BrewEntry brew) => _serial(() async {
    final index = beans.indexWhere((bean) => bean.id == brew.plan.beanId);
    if (index < 0) throw StateError('Biji tidak ditemukan.');
    if (beans[index].stockG < brew.plan.doseG) {
      throw StateError('Stok biji tidak cukup.');
    }
    final nextBeans = [...beans];
    nextBeans[index] = nextBeans[index].copyWith(
      stockG: nextBeans[index].stockG - brew.plan.doseG,
    );
    await _write(nextBeans, [brew, ...brews]);
  });

  Future<void> saveDiagnosis(String brewId, AiDiagnosis diagnosis) =>
      _serial(() async {
        final next = brews
            .map(
              (brew) => brew.id == brewId
                  ? brew.copyWith(aiDiagnosis: diagnosis)
                  : brew,
            )
            .toList();
        await _write(beans, next);
      });

  Future<void> _serial(Future<void> Function() operation) {
    final run = _pending.then((_) => operation());
    _pending = run.catchError((_) {});
    return run;
  }

  Future<void> _write(List<Bean> nextBeans, List<BrewEntry> nextBrews) async {
    await _box.put('data', {
      'beans': nextBeans.map((item) => item.toMap()).toList(),
      'brews': nextBrews.map((item) => item.toMap()).toList(),
    });
    beans = nextBeans;
    brews = nextBrews;
  }

  Future<void> close() => _box.close();
}
