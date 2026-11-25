abstract final class TasteTags {
  static const builtIn = [
    'asam',
    'pahit',
    'hambar',
    'seimbang',
    'manis',
    'cokelat',
    'buah',
    'kacang',
    'floral',
    'karamel',
    'rempah',
  ];
}

class Bean {
  const Bean({
    required this.id,
    required this.name,
    required this.roastery,
    required this.origin,
    required this.stockG,
    required this.price,
    required this.currency,
    required this.tastingNotes,
    this.species,
    this.beanType,
    this.arabicaPercent,
    this.isSelfRoasted = false,
    this.process,
    this.processCustom,
    this.roastLevel,
    this.roastDate,
    this.packSizeG,
    this.packPrice,
    this.tastingTags = const [],
  });

  final String id;
  final String name;
  final String roastery;
  final String origin;
  final double stockG;
  final double price; // Harga per kg; tetap untuk data yang sudah tersimpan.
  final String currency;
  final String tastingNotes;
  final String? species;
  final String? beanType;
  final int? arabicaPercent;
  final bool isSelfRoasted;
  final String? process;
  final String? processCustom;
  final String? roastLevel;
  final String? roastDate;
  final double? packSizeG;
  final double? packPrice;
  final List<String> tastingTags;

  Bean copyWith({double? stockG}) => Bean(
    id: id,
    name: name,
    roastery: roastery,
    origin: origin,
    stockG: stockG ?? this.stockG,
    price: price,
    currency: currency,
    tastingNotes: tastingNotes,
    species: species,
    beanType: beanType,
    arabicaPercent: arabicaPercent,
    isSelfRoasted: isSelfRoasted,
    process: process,
    processCustom: processCustom,
    roastLevel: roastLevel,
    roastDate: roastDate,
    packSizeG: packSizeG,
    packPrice: packPrice,
    tastingTags: tastingTags,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'roastery': roastery,
    'origin': origin,
    'stockG': stockG,
    'price': price,
    'currency': currency,
    'tastingNotes': tastingNotes,
    'species': species,
    'beanType': beanType,
    'arabicaPercent': arabicaPercent,
    'isSelfRoasted': isSelfRoasted,
    'process': process,
    'processCustom': processCustom,
    'roastLevel': roastLevel,
    'roastDate': roastDate,
    'packSizeG': packSizeG,
    'packPrice': packPrice,
    'tastingTags': tastingTags,
  };

  factory Bean.fromMap(Map<dynamic, dynamic> value) => Bean(
    id: value['id'] as String,
    name: value['name'] as String,
    roastery: value['roastery'] as String? ?? '',
    origin: value['origin'] as String? ?? '',
    stockG: (value['stockG'] as num).toDouble(),
    price: (value['price'] as num? ?? 0).toDouble(),
    currency: value['currency'] as String? ?? 'IDR',
    tastingNotes: value['tastingNotes'] as String? ?? '',
    species: value['species'] as String?,
    beanType: value['beanType'] as String?,
    arabicaPercent: (value['arabicaPercent'] as num?)?.toInt(),
    isSelfRoasted: value['isSelfRoasted'] == true,
    process: value['process'] as String?,
    processCustom: value['processCustom'] as String?,
    roastLevel: value['roastLevel'] as String?,
    roastDate: value['roastDate'] as String?,
    packSizeG: (value['packSizeG'] as num?)?.toDouble(),
    packPrice: (value['packPrice'] as num?)?.toDouble(),
    tastingTags: (value['tastingTags'] as List? ?? const [])
        .map((tag) => tag as String)
        .toList(),
  );
}

class BrewStage {
  const BrewStage(this.name, this.durationS, this.waterG);

  final String name;
  final int durationS;
  final double waterG;

  String get displayName => name.replaceFirst('Pouring', 'Tuangan');

  Map<String, dynamic> toMap() => {
    'name': name,
    'durationS': durationS,
    'waterG': waterG,
  };

  factory BrewStage.fromMap(Map<dynamic, dynamic> value) => BrewStage(
    value['name'] as String,
    value['durationS'] as int,
    (value['waterG'] as num).toDouble(),
  );
}

class BrewPlan {
  const BrewPlan({
    required this.beanId,
    required this.beanName,
    required this.doseG,
    required this.ratio,
    required this.temperatureC,
    required this.grind,
    required this.pouringCount,
    this.customStages,
  });

  final String beanId;
  final String beanName;
  final double doseG;
  final double ratio;
  final int temperatureC;
  final String grind;
  final int pouringCount;
  final List<BrewStage>? customStages;

  double get totalWaterG => doseG * ratio;

  // Rencana lama tetap memakai tahapan lama agar jurnal yang tersimpan tidak berubah.
  List<BrewStage> get stages {
    if (customStages != null) return customStages!;
    if (pouringCount == 1) {
      return [
        BrewStage('Tuang', 60, totalWaterG),
        BrewStage('Tunggu turun', 60, totalWaterG),
      ];
    }
    final bloom = doseG * 2.5;
    final remaining = totalWaterG - bloom;
    return [
      BrewStage('Bloom', 40, bloom),
      for (var i = 1; i < pouringCount; i++)
        BrewStage(
          'Tuang $i',
          30,
          i == pouringCount - 1
              ? totalWaterG
              : bloom + remaining * i / (pouringCount - 1),
        ),
      BrewStage('Tunggu turun', 60, totalWaterG),
    ];
  }

  static List<BrewStage> defaultPourStages(
    double doseG,
    double ratio,
    int pouringCount,
  ) {
    if (!doseG.isFinite ||
        !ratio.isFinite ||
        pouringCount < 1 ||
        pouringCount > 5) {
      throw const FormatException('Rencana tuang tidak valid.');
    }
    final total = doseG * ratio;
    if (pouringCount == 1) {
      return [BrewStage('Pouring 1', 60, total)];
    }
    final bloom = doseG * 3;
    final following = ((total - bloom) / (pouringCount - 1)).roundToDouble();
    final stages = <BrewStage>[BrewStage('Pouring 1 · Bloom', 40, bloom)];
    var assigned = bloom;
    for (var i = 2; i <= pouringCount; i++) {
      final water = i == pouringCount ? total - assigned : following;
      stages.add(BrewStage('Pouring $i', 30, water));
      assigned += water;
    }
    return stages;
  }

  Map<String, dynamic> toMap() => {
    'beanId': beanId,
    'beanName': beanName,
    'doseG': doseG,
    'ratio': ratio,
    'temperatureC': temperatureC,
    'grind': grind,
    'pouringCount': pouringCount,
    if (customStages != null)
      'stages': customStages!.map((stage) => stage.toMap()).toList(),
  };

  factory BrewPlan.fromMap(Map<dynamic, dynamic> value) => BrewPlan(
    beanId: value['beanId'] as String,
    beanName: value['beanName'] as String,
    doseG: (value['doseG'] as num).toDouble(),
    ratio: (value['ratio'] as num).toDouble(),
    temperatureC: value['temperatureC'] as int,
    grind: value['grind'] as String,
    pouringCount: value['pouringCount'] as int,
    customStages: (value['stages'] as List?)
        ?.map((stage) => BrewStage.fromMap(stage as Map))
        .toList(),
  );
}

class AiDiagnosis {
  const AiDiagnosis({required this.text, this.nextPlan, this.note = ''});

  final String text;
  final BrewPlan? nextPlan;
  final String note;

  Map<String, dynamic> toMap() => {
    'text': text,
    if (nextPlan != null) 'nextPlan': nextPlan!.toMap(),
    if (note.isNotEmpty) 'note': note,
  };

  factory AiDiagnosis.fromMap(dynamic value) {
    if (value is String) return AiDiagnosis(text: value);
    if (value is! Map) return const AiDiagnosis(text: '');
    return AiDiagnosis(
      text: value['text'] as String? ?? '',
      nextPlan: value['nextPlan'] is Map
          ? BrewPlan.fromMap(value['nextPlan'] as Map)
          : null,
      note: value['note'] as String? ?? '',
    );
  }
}

class BrewEntry {
  const BrewEntry({
    required this.id,
    required this.plan,
    required this.brewedAt,
    required this.durationS,
    required this.score,
    required this.notes,
    this.tasteTags = const [],
    this.customTasteTags = const [],
    this.actualWaterG = const [],
    this.drawdownS,
    this.aiDiagnosis,
  });

  final String id;
  final BrewPlan plan;
  final DateTime brewedAt;
  final int durationS;
  final int score;
  final String notes;
  final List<String> tasteTags;
  final List<String> customTasteTags;
  final List<double?> actualWaterG;
  final int? drawdownS;
  final AiDiagnosis? aiDiagnosis;

  static List<double?> actualPours(List<double?> readings, int stageCount) {
    if (readings.length != stageCount) {
      throw const FormatException('Jumlah angka timbangan tidak sesuai tahap.');
    }
    final pours = <double?>[];
    var previous = 0.0;
    for (final reading in readings) {
      if (reading == null) {
        pours.add(null);
        continue;
      }
      if (!reading.isFinite || reading < previous) {
        throw const FormatException(
          'Angka timbangan harus bertambah di tiap tahap.',
        );
      }
      pours.add(double.parse((reading - previous).toStringAsFixed(2)));
      previous = reading;
    }
    return pours;
  }

  BrewEntry copyWith({AiDiagnosis? aiDiagnosis}) => BrewEntry(
    id: id,
    plan: plan,
    brewedAt: brewedAt,
    durationS: durationS,
    score: score,
    notes: notes,
    tasteTags: tasteTags,
    customTasteTags: customTasteTags,
    actualWaterG: actualWaterG,
    drawdownS: drawdownS,
    aiDiagnosis: aiDiagnosis ?? this.aiDiagnosis,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'plan': plan.toMap(),
    'brewedAt': brewedAt.toUtc().toIso8601String(),
    'durationS': durationS,
    'score': score,
    'notes': notes,
    'tasteTags': tasteTags,
    'customTasteTags': customTasteTags,
    'actualWaterG': actualWaterG,
    'drawdownS': drawdownS,
    if (aiDiagnosis != null) 'aiDiagnosis': aiDiagnosis!.toMap(),
  };

  factory BrewEntry.fromMap(Map<dynamic, dynamic> value) => BrewEntry(
    id: value['id'] as String,
    plan: BrewPlan.fromMap(value['plan'] as Map),
    brewedAt: DateTime.parse(value['brewedAt'] as String),
    durationS: value['durationS'] as int,
    score: value['score'] as int,
    notes: value['notes'] as String? ?? '',
    tasteTags: (value['tasteTags'] as List? ?? const [])
        .map((tag) => tag as String)
        .toList(),
    customTasteTags: (value['customTasteTags'] as List? ?? const [])
        .map((tag) => tag as String)
        .toList(),
    actualWaterG: (value['actualWaterG'] as List? ?? const [])
        .map((water) => (water as num?)?.toDouble())
        .toList(),
    drawdownS: (value['drawdownS'] as num?)?.toInt(),
    aiDiagnosis: value['aiDiagnosis'] == null
        ? null
        : AiDiagnosis.fromMap(value['aiDiagnosis']),
  );
}
