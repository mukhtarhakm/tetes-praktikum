import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

import '../app/app_controller.dart';
import '../app/app_theme.dart';
import '../app/app_ui.dart';
import '../data/models.dart';
import '../data/brew_session_progress.dart';
import '../data/services.dart';
import 'beans_screen.dart';
import 'journal_screen.dart';

// LAYAR: atur resep dan urutan tuang sebelum mulai seduh.
class BrewSetupScreen extends StatefulWidget {
  const BrewSetupScreen({
    super.key,
    required this.controller,
    this.initialBeanId,
    this.initialPlan,
    this.initialAiNote,
  });
  final AppController controller;
  final String? initialBeanId;
  final BrewPlan? initialPlan;
  final String? initialAiNote;

  @override
  State<BrewSetupScreen> createState() => _BrewSetupScreenState();
}

class _BrewSetupScreenState extends State<BrewSetupScreen> {
  late String? beanId =
      widget.initialPlan?.beanId ??
      widget.initialBeanId ??
      (widget.controller.beans.isEmpty
          ? null
          : widget.controller.beans.first.id);
  late final dose = TextEditingController(
    text: widget.initialPlan?.doseG.toString() ?? '15',
  );
  late final ratio = TextEditingController(
    text: widget.initialPlan?.ratio.toString() ?? '16',
  );
  late final temperature = TextEditingController(
    text: widget.initialPlan?.temperatureC.toString() ?? '92',
  );
  late String grind = widget.initialPlan?.grind ?? 'Sedang';
  late int pouringCount = widget.initialPlan?.pouringCount ?? 3;
  bool aiBusy = false;
  AiRecommendation? aiSuggestion;
  late List<BrewStage>? editedStages = widget.initialPlan?.customStages;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPlan;
    if (initial != null &&
        initial.customStages != null &&
        widget.initialAiNote?.isNotEmpty == true) {
      aiSuggestion = AiRecommendation(
        doseG: initial.doseG,
        ratio: initial.ratio,
        temperatureC: initial.temperatureC,
        grind: initial.grind,
        stages: initial.customStages!,
        note: widget.initialAiNote!,
      );
    }
  }

  @override
  void dispose() {
    dose.dispose();
    ratio.dispose();
    temperature.dispose();
    super.dispose();
  }

  Bean? get selectedBean {
    final matches = widget.controller.beans.where((bean) => bean.id == beanId);
    return matches.isEmpty ? null : matches.first;
  }

  double? get totalWaterPreview {
    final doseG = double.tryParse(dose.text.replaceAll(',', '.'));
    final ratioValue = double.tryParse(ratio.text.replaceAll(',', '.'));
    if (doseG == null ||
        ratioValue == null ||
        !doseG.isFinite ||
        !ratioValue.isFinite ||
        doseG <= 0 ||
        ratioValue <= 0) {
      return null;
    }
    return doseG * ratioValue;
  }

  String clock(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

  BrewPlan? plan({bool showError = true}) {
    final bean = selectedBean;
    final doseG = double.tryParse(dose.text.replaceAll(',', '.'));
    final ratioValue = double.tryParse(ratio.text.replaceAll(',', '.'));
    final temp = int.tryParse(temperature.text);
    if (bean == null ||
        doseG == null ||
        !doseG.isFinite ||
        doseG < 5 ||
        doseG > 40 ||
        ratioValue == null ||
        !ratioValue.isFinite ||
        ratioValue < 10 ||
        ratioValue > 20 ||
        temp == null ||
        temp < 80 ||
        temp > 100 ||
        doseG > bean.stockG) {
      if (showError) {
        showAppMessage(
          context,
          'Periksa biji, stok, dosis (5–40 g), rasio (10–20), dan suhu (80–100 °C).',
        );
      }
      return null;
    }
    return BrewPlan(
      beanId: bean.id,
      beanName: bean.name,
      doseG: doseG,
      ratio: ratioValue,
      temperatureC: temp,
      grind: grind,
      pouringCount: pouringCount,
      customStages:
          editedStages ??
          BrewPlan.defaultPourStages(doseG, ratioValue, pouringCount),
    );
  }

  Widget stagePreview(BrewPlan preview, int index) {
    final stage = preview.stages[index];
    final start = preview.stages
        .take(index)
        .fold<int>(0, (sum, item) => sum + item.durationS);
    final end = start + stage.durationS;
    final cumulative = preview.stages
        .take(index + 1)
        .fold<double>(0, (sum, item) => sum + item.waterG);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: AppSpace.md),
        Row(
          children: [
            Text(
              '${(index + 1).toString().padLeft(2, '0')}.',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: AppColors.olive),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Text(
                index == 0 && preview.stages.length > 1
                    ? 'Bloom'
                    : 'Tuangan ${index + 1}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Text(
              '+${stage.waterG.toStringAsFixed(0)} g',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        Text('${clock(start)} - ${clock(end)}', style: AppTheme.stageTime),
        const SizedBox(height: AppSpace.xs),
        Text(
          '≈ ${stage.waterG.toStringAsFixed(0)} ml · ${stage.durationS} detik',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        Text(
          'Target timbangan ${cumulative.toStringAsFixed(0)} g',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
        ),
        TextButton.icon(
          onPressed: () => editStage(index),
          icon: const Icon(Icons.edit_outlined),
          label: Text(
            index == preview.stages.length - 1
                ? 'Ubah durasi'
                : 'Ubah durasi atau air',
          ),
        ),
        const SizedBox(height: AppSpace.md),
      ],
    );
  }

  Future<void> editStage(int index) async {
    final current = plan(showError: false);
    if (current == null) return;
    final stage = current.stages[index];
    var durationInput = stage.durationS.toString();
    var waterInput = stage.waterG.toStringAsFixed(0);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Ubah ${stage.displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: durationInput,
              onChanged: (value) => durationInput = value,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Durasi (detik)'),
            ),
            const SizedBox(height: AppSpace.md),
            TextFormField(
              initialValue: waterInput,
              onChanged: (value) => waterInput = value,
              enabled: index < current.stages.length - 1,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: index == current.stages.length - 1
                    ? 'Air tahap terakhir (otomatis)'
                    : 'Air yang dituang (g ≈ ml)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (saved == true) {
      final seconds = int.tryParse(durationInput.trim());
      final grams = double.tryParse(waterInput.trim().replaceAll(',', '.'));
      if (seconds == null ||
          seconds < 5 ||
          seconds > 120 ||
          grams == null ||
          !grams.isFinite ||
          grams <= 0) {
        showAppMessage(
          context,
          'Durasi harus 5–120 detik dan air lebih dari 0 g.',
        );
      } else {
        final stages = [...current.stages];
        stages[index] = BrewStage(stage.name, seconds, grams);
        if (index < stages.length - 1) {
          final assigned = stages
              .take(stages.length - 1)
              .fold<double>(0, (sum, item) => sum + item.waterG);
          final remaining = current.totalWaterG - assigned;
          if (remaining <= 0) {
            showAppMessage(context, 'Sisakan air untuk pouring terakhir.');
          } else {
            final last = stages.last;
            stages[stages.length - 1] = BrewStage(
              last.name,
              last.durationS,
              remaining,
            );
            setState(() {
              editedStages = stages;
              aiSuggestion = null;
            });
          }
        } else {
          setState(() {
            editedStages = stages;
            aiSuggestion = null;
          });
        }
      }
    }
  }

  Future<AiPreferences?> aiPreferences(Bean bean) async {
    var goal = '';
    final locked = <String>{};
    final doseValue = double.tryParse(dose.text.replaceAll(',', '.'));
    final ratioValue = double.tryParse(ratio.text.replaceAll(',', '.'));
    final temperatureValue = int.tryParse(temperature.text);
    final options = [
      (
        'dose',
        'Dosis ${dose.text} g',
        doseValue != null &&
            doseValue >= 5 &&
            doseValue <= 40 &&
            doseValue <= bean.stockG,
      ),
      (
        'ratio',
        'Rasio 1:${ratio.text}',
        ratioValue != null && ratioValue >= 10 && ratioValue <= 20,
      ),
      (
        'temperature',
        'Suhu ${temperature.text} °C',
        temperatureValue != null &&
            temperatureValue >= 80 &&
            temperatureValue <= 100,
      ),
      ('grind', 'Gilingan $grind', true),
      ('pouring', '$pouringCount tuangan', true),
    ];
    final result = await showModalBottomSheet<AiPreferences>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, updateSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xl,
                0,
                AppSpace.xl,
                AppSpace.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Saran untuk ${bean.name}',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  const Text('Kosongkan pilihan untuk saran langsung.'),
                  const SizedBox(height: AppSpace.lg),
                  TextField(
                    onChanged: (value) => goal = value,
                    maxLength: 200,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Ingin hasil seperti apa? (opsional)',
                      hintText: 'Misalnya lebih manis, tidak watery',
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    'Pertahankan isian ini',
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Wrap(
                    spacing: AppSpace.sm,
                    runSpacing: AppSpace.sm,
                    children: [
                      for (final option in options)
                        FilterChip(
                          label: Text(option.$2),
                          selected: locked.contains(option.$1),
                          onSelected: option.$3
                              ? (selected) => updateSheet(() {
                                  if (selected) {
                                    locked.add(option.$1);
                                  } else {
                                    locked.remove(option.$1);
                                  }
                                })
                              : null,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.xxl),
                  AppButton(
                    label: 'Buat saran',
                    icon: Icons.auto_awesome_rounded,
                    onPressed: () => Navigator.pop(
                      sheetContext,
                      AiPreferences(
                        goal: goal,
                        doseG: locked.contains('dose') ? doseValue : null,
                        ratio: locked.contains('ratio') ? ratioValue : null,
                        temperatureC: locked.contains('temperature')
                            ? temperatureValue
                            : null,
                        grind: locked.contains('grind') ? grind : null,
                        pouringCount: locked.contains('pouring')
                            ? pouringCount
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return result;
  }

  Widget aiPlanSummary(AiRecommendation suggestion) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '${suggestion.doseG.toStringAsFixed(1)} g kopi · '
        '1:${suggestion.ratio.toStringAsFixed(1)} · '
        '${suggestion.temperatureC} °C',
      ),
      Text(
        '${suggestion.grind} · '
        '${suggestion.pouringCount} tuangan · '
        '${(suggestion.doseG * suggestion.ratio).toStringAsFixed(0)} g air',
      ),
      const SizedBox(height: AppSpace.md),
      for (var i = 0; i < suggestion.stages.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.xs),
          child: Text(
            '${i == 0 && suggestion.stages.length > 1 ? 'Bloom' : 'Tuangan ${i + 1}'}: '
            '${suggestion.stages[i].durationS} detik · '
            '${suggestion.stages[i].waterG.toStringAsFixed(0)} g',
          ),
        ),
      const SizedBox(height: AppSpace.md),
      Text(suggestion.note),
    ],
  );

  Future<void> askAi() async {
    final bean = selectedBean;
    if (bean == null) return;
    final preferences = await aiPreferences(bean);
    if (preferences == null || !mounted || selectedBean?.id != bean.id) return;
    setState(() => aiBusy = true);
    try {
      final suggestion = await widget.controller.recommend(bean, preferences);
      if (!mounted || selectedBean?.id != bean.id) return;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Tinjau rencana AI'),
          content: SingleChildScrollView(child: aiPlanSummary(suggestion)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Terapkan'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted || selectedBean?.id != bean.id) return;
      setState(() {
        dose.text = suggestion.doseG.toString();
        ratio.text = suggestion.ratio.toString();
        temperature.text = suggestion.temperatureC.toString();
        grind = suggestion.grind;
        pouringCount = suggestion.pouringCount;
        editedStages = suggestion.stages;
        aiSuggestion = suggestion;
      });
    } catch (_) {
      if (mounted) {
        showAppMessage(
          context,
          'Saran AI belum tersedia. Kamu tetap bisa memakai pengaturan manual.',
        );
      }
    } finally {
      if (mounted) setState(() => aiBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      if (widget.controller.beans.isEmpty) {
        return Scaffold(
          appBar: AppBar(title: const Text('Atur seduh')),
          body: AppStateView(
            icon: Icons.grain_rounded,
            message: 'Tambahkan beans sebelum mulai seduh.',
            action: 'Tambah beans',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BeansScreen(controller: widget.controller),
              ),
            ),
          ),
        );
      }
      final preview = plan(showError: false);
      final totalWater = totalWaterPreview;
      return Scaffold(
        appBar: AppBar(title: const Text('Atur seduh')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.xl,
            AppSpace.lg,
            AppSpace.xl,
            AppSpace.section,
          ),
          children: [
            // TAMPILAN ATUR SEDUH: judul halaman.
            Text('Rencana seduhmu', style: AppTheme.pageTitle),
            const SizedBox(height: AppSpace.xxl),
            // TAMPILAN ATUR SEDUH: pilih beans untuk resep ini.
            DropdownButtonFormField<String>(
              key: ValueKey(selectedBean?.id),
              initialValue: selectedBean?.id,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Beans'),
              items: widget.controller.beans
                  .map(
                    (bean) => DropdownMenuItem(
                      value: bean.id,
                      child: Text(
                        bean.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                beanId = value;
                editedStages = null;
                aiSuggestion = null;
              }),
            ),
            const SizedBox(height: AppSpace.md),
            // TAMPILAN ATUR SEDUH: tombol permintaan saran AI.
            OutlinedButton.icon(
              // kalo mau ganti warna Minta saran AI
              // style: OutlinedButton.styleFrom(
              //   backgroundColor: Colors.red.shade50,
              //   foregroundColor: Colors.red,
              //   side: const BorderSide(color: Colors.red),
              // ),
              onPressed: aiBusy ? null : askAi,
              icon: aiBusy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: const Text('Minta saran AI'),
            ),
            if (aiSuggestion != null) ...[
              const SizedBox(height: AppSpace.md),
              AppCard(
                color: AppColors.oliveSoft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saran AI',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpace.sm),
                    aiPlanSummary(aiSuggestion!),
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      'Saran, bukan kepastian. Coba dan catat hasilnya.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpace.xxl),
            // TAMPILAN ATUR SEDUH: dosis dan rasio.
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: dose,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Dosis (g)'),
                    onChanged: (_) => setState(() {
                      editedStages = null;
                      aiSuggestion = null;
                    }),
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: TextField(
                    controller: ratio,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Rasio 1 :'),
                    onChanged: (_) => setState(() {
                      editedStages = null;
                      aiSuggestion = null;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            TextField(
              controller: temperature,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Suhu air (°C)'),
              onChanged: (_) => setState(() => aiSuggestion = null),
            ),
            const SizedBox(height: AppSpace.lg),
            DropdownButtonFormField<String>(
              key: ValueKey(grind),
              initialValue: grind,
              decoration: const InputDecoration(labelText: 'Gilingan'),
              items: const ['Halus', 'Sedang', 'Kasar']
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                grind = value ?? 'Sedang';
                aiSuggestion = null;
              }),
            ),
            const SizedBox(height: AppSpace.xxl),
            const Divider(),
            const SizedBox(height: AppSpace.lg),
            // TAMPILAN ATUR SEDUH: hasil hitung total air.
            Text(
              'TOTAL AIR',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.olive,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              '${totalWater?.toStringAsFixed(0) ?? '—'} g',
              style: AppTheme.totalWater,
            ),
            const SizedBox(height: AppSpace.lg),
            const Divider(),
            const SizedBox(height: AppSpace.xxl),
            // TAMPILAN ATUR SEDUH: jumlah tuangan dan urutan tahap.
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Jumlah tuangan',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text(
                  '$pouringCount',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            Slider(
              value: pouringCount.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: '$pouringCount',
              onChanged: (value) => setState(() {
                pouringCount = value.round();
                editedStages = null;
                aiSuggestion = null;
              }),
            ),
            const SizedBox(height: AppSpace.xxl),
            Text(
              'URUTAN TUANG',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.muted,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              'Rentang waktu mengikuti jam total sejak seduh dimulai.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpace.md),
            if (preview != null) ...[
              for (var i = 0; i < preview.stages.length; i++)
                stagePreview(preview, i),
              Text(
                'Setelah tuangan terakhir, tunggu air selesai menetes.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
            ] else
              const Text('Periksa pengaturan untuk melihat urutan tuang.'),
            const SizedBox(height: AppSpace.xxl),
            // TAMPILAN ATUR SEDUH: mulai sesi timer.
            AppButton(
              label: 'Mulai seduh',
              icon: Icons.play_arrow_rounded,
              onPressed: () {
                final value = plan();
                if (value == null) return;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BrewSessionScreen(
                      controller: widget.controller,
                      plan: value,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    },
  );
}

// LAYAR: jalankan timer dan panduan tuang selama sesi seduh.
class BrewSessionScreen extends StatefulWidget {
  const BrewSessionScreen({
    super.key,
    required this.controller,
    required this.plan,
  });
  final AppController controller;
  final BrewPlan plan;

  @override
  State<BrewSessionScreen> createState() => _BrewSessionScreenState();
}

class _BrewSessionScreenState extends State<BrewSessionScreen>
    with WidgetsBindingObserver {
  final stopwatch = Stopwatch();
  Timer? ticker;
  AudioPlayer? cuePlayer;
  int lastPhase = 0;
  bool foreground = true;
  bool cuesEnabled = true;
  bool finished = false;
  bool leaving = false;
  bool cancelDialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    stopwatch.start();
    ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => update());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground) update(playCue: false);
  }

  Future<void> playCue(bool drawdown) async {
    if (!cuesEnabled || !mounted) return;
    try {
      if (drawdown) {
        await HapticFeedback.heavyImpact();
      } else {
        await HapticFeedback.mediumImpact();
      }
    } catch (_) {
      // Perangkat tanpa getar tetap dapat memakai suara.
    }
    if (!cuesEnabled || !mounted) return;
    try {
      if (cuePlayer != null) await cuePlayer!.stop();
      final player = cuePlayer ??= AudioPlayer();
      await player.play(
        AssetSource(drawdown ? 'audio/drawdown.wav' : 'audio/pour.wav'),
        mode: PlayerMode.lowLatency,
        ctx: AudioContext(
          android: const AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );
      if (!cuesEnabled) await player.stop();
    } catch (_) {
      // Timer tetap berjalan jika audio perangkat tidak tersedia.
    }
  }

  void update({bool playCue = true}) {
    if (!mounted || finished) return;
    final progress = BrewSessionProgress(
      widget.plan,
      stopwatch.elapsed.inSeconds,
    );
    if (progress.drawdownElapsedSeconds >=
        BrewSessionProgress.maxDrawdownSeconds) {
      complete(
        recordDrawdown: false,
        durationS:
            progress.pourDurationSeconds +
            BrewSessionProgress.maxDrawdownSeconds,
      );
      return;
    }
    final phase = progress.isDrawdown
        ? widget.plan.stages.length
        : progress.stageIndex;
    if (phase != lastPhase) {
      lastPhase = phase;
      // shortcut: isyarat hanya saat layar sesi aktif; jadwalkan di latar jika diperlukan.
      if (playCue && foreground) {
        unawaited(this.playCue(progress.isDrawdown));
      }
    }
    setState(() {});
  }

  void complete({required bool recordDrawdown, int? durationS}) {
    if (finished) return;
    final elapsed = durationS ?? stopwatch.elapsed.inSeconds;
    final progress = BrewSessionProgress(widget.plan, elapsed);
    finished = true;
    ticker?.cancel();
    stopwatch.stop();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => BrewResultScreen(
          controller: widget.controller,
          plan: widget.plan,
          durationS: elapsed,
          measuredDrawdownS: recordDrawdown
              ? progress.drawdownElapsedSeconds
              : null,
        ),
      ),
    );
  }

  Future<void> requestCancel() async {
    if (cancelDialogOpen || leaving || finished) return;
    cancelDialogOpen = true;
    final cancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Batalkan sesi?'),
        content: const Text('Seduhan ini belum akan masuk jurnal.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Lanjut seduh'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Batalkan'),
          ),
        ],
      ),
    );
    cancelDialogOpen = false;
    if (cancel != true || !mounted) return;
    ticker?.cancel();
    stopwatch.stop();
    setState(() => leaving = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ticker?.cancel();
    stopwatch.stop();
    if (cuePlayer != null) unawaited(cuePlayer!.dispose());
    super.dispose();
  }

  String clock(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

  Widget stageStrip(BrewSessionProgress progress) => Wrap(
    alignment: WrapAlignment.center,
    spacing: AppSpace.md,
    runSpacing: AppSpace.sm,
    children: [
      for (var i = 0; i < widget.plan.stages.length; i++)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: AppColors.pourColors[i % AppColors.pourColors.length],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpace.xs),
            Text(
              '${i + 1} · ${i == 0 && widget.plan.stages.length > 1 ? 'Bloom' : 'Tuang'}${i < progress.stageIndex ? ' ✓' : ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: i == progress.stageIndex
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
          ],
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final progress = BrewSessionProgress(
      widget.plan,
      stopwatch.elapsed.inSeconds,
    );
    final drawdown = progress.isDrawdown;
    final stage = widget.plan.stages[progress.stageIndex];
    final ringSize = math.min(280.0, MediaQuery.sizeOf(context).width - 48);
    final color =
        AppColors.pourColors[progress.stageIndex % AppColors.pourColors.length];
    final nextIndex = progress.stageIndex + 1;
    return PopScope(
      canPop: leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(requestCancel());
      },
      child: Scaffold(
        appBar: AppBar(
          leadingWidth: 106,
          leading: TextButton.icon(
            onPressed: requestCancel,
            icon: const Icon(Icons.close_rounded),
            label: const Text('Keluar'),
          ),
          title: Text(
            widget.plan.beanName,
            style: AppTheme.sessionCoffeeName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              tooltip: cuesEnabled
                  ? 'Matikan suara dan getar'
                  : 'Aktifkan suara dan getar',
              onPressed: () {
                setState(() => cuesEnabled = !cuesEnabled);
                if (!cuesEnabled && cuePlayer != null) {
                  unawaited(cuePlayer!.stop());
                }
              },
              icon: Icon(
                cuesEnabled
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
              ),
            ),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xl,
              AppSpace.lg,
              AppSpace.xl,
              AppSpace.section,
            ),
            children: [
              // TAMPILAN TIMER: ringkasan resep dan nama tahap aktif.
              Center(
                child: Text(
                  '${widget.plan.doseG.toStringAsFixed(0)} g kopi · ${widget.plan.totalWaterG.toStringAsFixed(0)} g air',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const SizedBox(height: AppSpace.section),
              Center(
                child: Text(
                  drawdown
                      ? 'DRAWDOWN · AIR MENETES'
                      : 'TUANGAN ${progress.stageIndex + 1} DARI ${widget.plan.stages.length}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(letterSpacing: 1.5),
                ),
              ),
              const SizedBox(height: AppSpace.xxl),
              // TAMPILAN TIMER: lingkaran progres dan waktu.
              Center(
                child: SizedBox.square(
                  dimension: ringSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: drawdown
                            ? DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.border,
                                    width: 8,
                                  ),
                                ),
                              )
                            : CircularProgressIndicator(
                                value: progress.stageProgress,
                                strokeWidth: 8,
                                strokeCap: StrokeCap.round,
                                backgroundColor: AppColors.border,
                                color: color,
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(AppSpace.xxl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'WAKTU TOTAL',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(letterSpacing: 1.5),
                            ),
                            const SizedBox(height: AppSpace.md),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                clock(progress.elapsedSeconds),
                                style: AppTheme.timer,
                              ),
                            ),
                            if (!drawdown) ...[
                              const SizedBox(height: AppSpace.md),
                              Text(
                                'Tuangan ini ${clock(progress.stageElapsedSeconds)} / ${clock(stage.durationS)}',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.xxl),
              // TAMPILAN TIMER: aksi drawdown atau target tuangan.
              if (drawdown) ...[
                Center(
                  child: Text(
                    'Drawdown  ${clock(progress.drawdownElapsedSeconds)}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: AppSpace.xxl),
                const Divider(),
                const SizedBox(height: AppSpace.lg),
                const Center(child: Text('Tunggu sampai air selesai menetes.')),
                const SizedBox(height: AppSpace.xxl),
                AppButton(
                  label: 'Air habis',
                  icon: Icons.check_rounded,
                  onPressed: () => complete(recordDrawdown: true),
                ),
                const SizedBox(height: AppSpace.sm),
                TextButton(
                  onPressed: () => complete(recordDrawdown: false),
                  child: const Text('Lewati drawdown'),
                ),
                const SizedBox(height: AppSpace.xxl),
                const Divider(),
                Center(
                  child: Text(
                    'Waktu drawdown akan dicatat di hasil seduh.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'Tuang sekarang',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            '+${stage.waterG.toStringAsFixed(0)} g',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 54,
                      child: VerticalDivider(width: AppSpace.xl),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'Target timbangan',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            '${progress.cumulativeWaterAt(progress.stageIndex).toStringAsFixed(0)} g',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.section),
                stageStrip(progress),
                const SizedBox(height: AppSpace.xxl),
                const Divider(),
                const SizedBox(height: AppSpace.md),
                Center(
                  child: Text(
                    nextIndex < widget.plan.stages.length
                        ? 'Berikutnya +${widget.plan.stages[nextIndex].waterG.toStringAsFixed(0)} g · timbangan ${progress.cumulativeWaterAt(nextIndex).toStringAsFixed(0)} g'
                        : 'Setelah ini: tunggu air selesai menetes.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// LAYAR: catat skor, rasa, dan hasil pengukuran seduhan.
class BrewResultScreen extends StatefulWidget {
  const BrewResultScreen({
    super.key,
    required this.controller,
    required this.plan,
    required this.durationS,
    this.measuredDrawdownS,
  });
  final AppController controller;
  final BrewPlan plan;
  final int durationS;
  final int? measuredDrawdownS;

  @override
  State<BrewResultScreen> createState() => _BrewResultScreenState();
}

class _BrewResultScreenState extends State<BrewResultScreen> {
  int score = 0;
  final tags = <String>{};
  final customTags = TextEditingController();
  final notes = TextEditingController();
  late final drawdown = TextEditingController(
    text: widget.measuredDrawdownS?.toString() ?? '',
  );
  late final water = List.generate(
    widget.plan.stages.length,
    (_) => TextEditingController(),
  );
  bool busy = false;

  @override
  void dispose() {
    customTags.dispose();
    notes.dispose();
    drawdown.dispose();
    for (final input in water) {
      input.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (score == 0 || tags.isEmpty) {
      showAppMessage(context, 'Pilih skor dan minimal satu rasa.');
      return;
    }
    final readings = <double?>[];
    for (final input in water) {
      final raw = input.text.trim().replaceAll(',', '.');
      final value = raw.isEmpty ? null : double.tryParse(raw);
      if (raw.isNotEmpty && value == null) {
        showAppMessage(context, 'Angka timbangan harus berupa angka.');
        return;
      }
      readings.add(value);
    }
    final rawDrawdown = drawdown.text.trim();
    final drawdownS = rawDrawdown.isEmpty ? null : int.tryParse(rawDrawdown);
    if (rawDrawdown.isNotEmpty && drawdownS == null) {
      showAppMessage(context, 'Waktu drawdown harus dalam detik.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Simpan seduhan?'),
        content: const Text(
          'Data seduhan tidak dapat diubah setelah disimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      final entry = await widget.controller.saveBrew(
        widget.plan,
        widget.durationS,
        score,
        notes.text,
        tasteTags: tags.toList(),
        customTasteTags: customTags.text
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList(),
        cumulativeWaterG: readings,
        drawdownS: drawdownS,
      );
      if (!mounted) return;
      final navigator = Navigator.of(context);
      navigator.popUntil((route) => route.isFirst);
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              BrewDetailScreen(controller: widget.controller, brewId: entry.id),
        ),
      );
    } on FormatException catch (error) {
      if (mounted) showAppMessage(context, error.message);
    } catch (_) {
      if (mounted) {
        showAppMessage(
          context,
          'Seduhan belum bisa disimpan. Periksa stok biji.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final beans = widget.controller.beans.where(
      (bean) => bean.id == plan.beanId,
    );
    final bean = beans.isEmpty ? null : beans.first;
    final cost = bean != null && bean.currency == 'IDR' && bean.price > 0
        ? plan.doseG * bean.price / 1000
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Hasil seduh')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.xl),
        children: [
          // TAMPILAN HASIL: ringkasan resep yang baru diseduh.
          AppCard(
            color: AppColors.oliveSoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.beanName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  '${plan.doseG.toStringAsFixed(1)} g · 1:${plan.ratio.toStringAsFixed(1)} · ${plan.temperatureC} °C',
                ),
                Text('Gilingan ${plan.grind} · ${plan.pouringCount} pouring'),
                Text(
                  'Durasi ${widget.durationS ~/ 60} menit ${widget.durationS % 60} detik',
                ),
                if (cost != null)
                  Text('Perkiraan biaya Rp ${cost.toStringAsFixed(0)}'),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xxl),
          // TAMPILAN HASIL: penilaian dan tag rasa.
          Text(
            'Gimana rasanya?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpace.sm),
          const Text('Pilih skor 1–5.'),
          Wrap(
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: 'Skor $i dari 5',
                  onPressed: () => setState(() => score = i),
                  icon: Icon(
                    i <= score ? Icons.star_rounded : Icons.star_border_rounded,
                    color: AppColors.warning,
                    size: 38,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Text(
            'Rasanya seperti apa?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpace.sm),
          const Text('Pilih minimal satu rasa.'),
          Wrap(
            spacing: AppSpace.sm,
            children: [
              for (final tag in TasteTags.builtIn)
                FilterChip(
                  label: Text(tag),
                  selected: tags.contains(tag),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      tags.add(tag);
                    } else {
                      tags.remove(tag);
                    }
                  }),
                ),
            ],
          ),
          TextField(
            controller: customTags,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Rasa lain (opsional)',
              hintText: 'Pisahkan dengan koma, maksimal 3',
            ),
          ),
          if (bean != null && bean.tastingTags.isNotEmpty)
            Text('Kata roastery: ${bean.tastingTags.join(', ')}'),
          const SizedBox(height: AppSpace.lg),
          // TAMPILAN HASIL: pengukuran air dan drawdown (opsional).
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Timbangan tiap pouring',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpace.sm),
                const Text(
                  'Opsional. Isi angka kumulatif yang terlihat di timbangan; air tiap tahap dihitung otomatis.',
                ),
                const SizedBox(height: AppSpace.md),
                for (var i = 0; i < plan.stages.length; i++) ...[
                  Text(
                    '${plan.stages[i].displayName} · target ${(plan.customStages == null ? plan.stages[i].waterG : plan.stages.take(i + 1).fold<double>(0, (sum, stage) => sum + stage.waterG)).toStringAsFixed(0)} g',
                  ),
                  const SizedBox(height: AppSpace.sm),
                  TextField(
                    controller: water[i],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Angka timbangan (g)',
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                ],
                TextField(
                  controller: drawdown,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Waktu drawdown (detik) · opsional',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          // TAMPILAN HASIL: catatan rasa tambahan.
          TextField(
            controller: notes,
            maxLines: 3,
            maxLength: 300,
            decoration: const InputDecoration(
              labelText: 'Catatan rasa (opsional)',
              hintText: 'Misalnya terasa watery, asam tajam, atau pahit',
            ),
          ),
          const SizedBox(height: AppSpace.xxl),
          // TAMPILAN HASIL: simpan ke jurnal.
          AppButton(
            label: 'Simpan ke jurnal',
            icon: Icons.save_rounded,
            onPressed: busy ? null : save,
            busy: busy,
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            'Diagnosa AI tersedia setelah menyimpan.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
