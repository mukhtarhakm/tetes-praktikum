import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/app_theme.dart';
import '../app/app_ui.dart';
import '../data/models.dart';
import 'brew_screen.dart';

// LAYAR: daftar, pencarian, dan filter riwayat seduhan.
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  String search = '';
  String? beanFilter;
  int? ratingFilter;

  List<BrewEntry> filtered({String? beanId, int? rating}) =>
      widget.controller.brews.where((brew) {
        final term = search.trim().toLowerCase();
        return (beanId == null || brew.plan.beanId == beanId) &&
            (rating == null || brew.score == rating) &&
            '${brew.plan.beanName} ${brew.notes}'.toLowerCase().contains(term);
      }).toList();

  Future<void> showFilters() async {
    var draftBean = beanFilter;
    var draftRating = ratingFilter;
    final names = <String, String>{
      for (final brew in widget.controller.brews)
        brew.plan.beanId: brew.plan.beanName,
    };
    final roasteries = <String, String>{
      for (final bean in widget.controller.beans) bean.id: bean.roastery,
    };
    final origins = <String, String>{
      for (final bean in widget.controller.beans) bean.id: bean.origin,
    };
    final selected = await showModalBottomSheet<(String?, int?)>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, updateSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Saring jurnal',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    TextButton(
                      onPressed: () => updateSheet(() {
                        draftBean = null;
                        draftRating = null;
                      }),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.lg),
                DropdownButtonFormField<String>(
                  key: ValueKey(draftBean),
                  initialValue: draftBean,
                  isExpanded: true,
                  hint: const Text('Semua beans'),
                  decoration: const InputDecoration(labelText: 'Beans'),
                  items: [
                    for (final entry in names.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(
                          [
                            entry.value,
                            if (roasteries[entry.key]?.isNotEmpty == true)
                              roasteries[entry.key]!,
                            if (origins[entry.key]?.isNotEmpty == true)
                              origins[entry.key]!,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => updateSheet(() => draftBean = value),
                ),
                const SizedBox(height: AppSpace.lg),
                Text('Rating', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: AppSpace.sm),
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  children: [
                    for (final score in <int?>[null, 5, 4, 3, 2, 1])
                      ChoiceChip(
                        label: Text(score == null ? 'Semua' : '$score ★'),
                        selected: draftRating == score,
                        onSelected: (_) =>
                            updateSheet(() => draftRating = score),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpace.xxl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.pop(sheetContext, (draftBean, draftRating)),
                    child: Text(
                      'Tampilkan ${filtered(beanId: draftBean, rating: draftRating).length} seduhan',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        beanFilter = selected.$1;
        ratingFilter = selected.$2;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final entries = filtered(beanId: beanFilter, rating: ratingFilter);
      final beanNames = <String, String>{
        for (final brew in widget.controller.brews)
          brew.plan.beanId: brew.plan.beanName,
      };
      return ColoredBox(
        color: Colors.transparent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.xl,
            AppSpace.lg,
            AppSpace.xl,
            AppSpace.xl,
          ),
          children: [
            // TAMPILAN JURNAL: judul, pencarian, dan filter.
            AppPageHeader(
              title: 'Jurnal',
              subtitle: '${widget.controller.brews.length} seduhan tercatat',
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) => setState(() => search = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Cari beans atau catatan',
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Badge(
                  isLabelVisible: beanFilter != null || ratingFilter != null,
                  child: IconButton.filledTonal(
                    tooltip: 'Saring jurnal',
                    onPressed: showFilters,
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ),
              ],
            ),
            if (beanFilter != null || ratingFilter != null) ...[
              const SizedBox(height: AppSpace.sm),
              Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.xs,
                children: [
                  if (beanFilter != null)
                    InputChip(
                      label: Text(
                        beanNames[beanFilter] ?? 'Beans tidak tersedia',
                      ),
                      onDeleted: () => setState(() => beanFilter = null),
                    ),
                  if (ratingFilter != null)
                    InputChip(
                      label: Text('$ratingFilter ★'),
                      onDeleted: () => setState(() => ratingFilter = null),
                    ),
                  TextButton(
                    onPressed: () => setState(() {
                      beanFilter = null;
                      ratingFilter = null;
                    }),
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ],
            Text(
              '${entries.length} seduhan',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpace.xxl),
            // TAMPILAN JURNAL: daftar seduhan dikelompokkan berdasarkan tanggal.
            if (entries.isEmpty)
              AppStateView(
                icon: Icons.menu_book_rounded,
                message: widget.controller.brews.isEmpty
                    ? 'Belum ada seduhan tersimpan.'
                    : 'Seduhan tidak ditemukan.',
              ),
            for (var i = 0; i < entries.length; i++) ...[
              if (i == 0 ||
                  !DateUtils.isSameDay(
                    entries[i].brewedAt.toLocal(),
                    entries[i - 1].brewedAt.toLocal(),
                  )) ...[
                Text(
                  _dateHeading(entries[i].brewedAt),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.muted,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpace.md),
              ],
              AppListRow(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BrewDetailScreen(
                      controller: widget.controller,
                      brewId: entries[i].id,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entries[i].plan.beanName,
                            style: Theme.of(context).textTheme.titleLarge,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpace.xs),
                          Text(
                            '${entries[i].plan.doseG.toStringAsFixed(0)} g · 1:${entries[i].plan.ratio.toStringAsFixed(1)}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Icon(Icons.star_rounded, size: 18, color: AppColors.olive),
                    Text(
                      ' ${entries[i].score}/5',
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: AppColors.olive),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

// Helper untuk memformat tanggal dan waktu yang ditampilkan di jurnal.
String _dateHeading(DateTime value) {
  const months = [
    'JANUARI',
    'FEBRUARI',
    'MARET',
    'APRIL',
    'MEI',
    'JUNI',
    'JULI',
    'AGUSTUS',
    'SEPTEMBER',
    'OKTOBER',
    'NOVEMBER',
    'DESEMBER',
  ];
  final local = value.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}

String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}

String _clock(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

// LAYAR: detail resep, hasil, pengukuran, dan diagnosa satu seduhan.
class BrewDetailScreen extends StatefulWidget {
  const BrewDetailScreen({
    super.key,
    required this.controller,
    required this.brewId,
  });
  final AppController controller;
  final String brewId;

  @override
  State<BrewDetailScreen> createState() => _BrewDetailScreenState();
}

class _BrewDetailScreenState extends State<BrewDetailScreen> {
  bool busy = false;

  Future<void> diagnose(BrewEntry brew) async {
    setState(() => busy = true);
    try {
      await widget.controller.diagnose(brew);
    } catch (_) {
      if (mounted) {
        showAppMessage(
          context,
          'Diagnosa AI belum tersedia. Coba lagi saat online.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void openSetup(BrewPlan plan, {String? aiNote}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BrewSetupScreen(
          controller: widget.controller,
          initialPlan: plan,
          initialAiNote: aiNote,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final matches = widget.controller.brews.where(
        (brew) => brew.id == widget.brewId,
      );
      if (matches.isEmpty) {
        return const Scaffold(
          body: AppStateView(
            icon: Icons.info_outline,
            message: 'Seduhan tidak ditemukan.',
          ),
        );
      }
      final brew = matches.first;
      final beanAvailable = widget.controller.beans.any(
        (bean) => bean.id == brew.plan.beanId,
      );
      final flavorTags = [...brew.tasteTags, ...brew.customTasteTags];
      final hasWaterReadings = brew.actualWaterG.any((value) => value != null);
      final sectionStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
        color: AppColors.muted,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w700,
      );
      Widget detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      );
      return Scaffold(
        appBar: AppBar(title: const Text('Detail seduhan')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.xl,
            AppSpace.lg,
            AppSpace.xl,
            AppSpace.section,
          ),
          children: [
            // TAMPILAN DETAIL: nama beans, tanggal, dan skor.
            Text(
              brew.plan.beanName,
              style: AppTheme.coffeeName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              _date(brew.brewedAt),
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpace.xxl),
            Row(
              children: [
                const Icon(Icons.star_rounded, color: AppColors.olive),
                const SizedBox(width: AppSpace.sm),
                Text(
                  '${brew.score}/5',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineLarge?.copyWith(color: AppColors.olive),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.xxl),
            const Divider(),
            const SizedBox(height: AppSpace.lg),
            // TAMPILAN DETAIL: resep dan aksi untuk menyeduh ulang.
            Text('RESEP', style: sectionStyle),
            const SizedBox(height: AppSpace.md),
            detailRow('Dosis', '${brew.plan.doseG.toStringAsFixed(1)} g'),
            detailRow(
              'Total air',
              '${brew.plan.totalWaterG.toStringAsFixed(0)} g',
            ),
            detailRow('Rasio', '1:${brew.plan.ratio.toStringAsFixed(1)}'),
            detailRow('Suhu air', '${brew.plan.temperatureC} °C'),
            detailRow('Gilingan', brew.plan.grind),
            detailRow('Tuangan', '${brew.plan.pouringCount}'),
            if (brew.plan.customStages != null) ...[
              const SizedBox(height: AppSpace.md),
              Text('URUTAN TUANG', style: sectionStyle),
              const SizedBox(height: AppSpace.sm),
              for (var i = 0; i < brew.plan.customStages!.length; i++)
                detailRow(
                  brew.plan.customStages![i].displayName,
                  '${_clock(brew.plan.customStages!.take(i).fold<int>(0, (sum, stage) => sum + stage.durationS))} - '
                  '${_clock(brew.plan.customStages!.take(i + 1).fold<int>(0, (sum, stage) => sum + stage.durationS))} · '
                  '${brew.plan.customStages![i].waterG.toStringAsFixed(0)} g',
                ),
            ],
            detailRow(
              'Waktu seduh',
              '${(brew.durationS ~/ 60).toString().padLeft(2, '0')}:${(brew.durationS % 60).toString().padLeft(2, '0')}',
            ),
            const SizedBox(height: AppSpace.lg),
            FilledButton.icon(
              onPressed: beanAvailable ? () => openSetup(brew.plan) : null,
              icon: const Icon(Icons.local_cafe_outlined),
              label: const Text('Seduh lagi dengan resep ini'),
            ),
            if (!beanAvailable)
              const Text('Beans untuk resep ini sudah tidak tersedia.'),
            if (brew.plan.customStages == null)
              const Text(
                'Tahapan tuang lama perlu ditinjau ulang di Atur Seduh.',
              ),
            const SizedBox(height: AppSpace.xxl),
            const Divider(),
            const SizedBox(height: AppSpace.lg),
            // TAMPILAN DETAIL: rasa, catatan, dan hasil pengukuran.
            Text('HASIL SEDUH', style: sectionStyle),
            const SizedBox(height: AppSpace.md),
            if (flavorTags.isNotEmpty) ...[
              Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.sm,
                children: [
                  for (final tag in flavorTags)
                    Chip(
                      label: Text(tag),
                      backgroundColor: AppColors.background,
                      side: const BorderSide(color: AppColors.olive),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
            ],
            if (brew.notes.isNotEmpty) ...[
              Text(brew.notes, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: AppSpace.md),
            ],
            if (brew.drawdownS != null)
              detailRow('Drawdown', '${brew.drawdownS} detik'),
            if (hasWaterReadings) ...[
              const SizedBox(height: AppSpace.md),
              Text(
                'Air tiap tuangan',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (
                var i = 0;
                i < brew.actualWaterG.length && i < brew.plan.stages.length;
                i++
              )
                if (brew.actualWaterG[i] != null)
                  detailRow(
                    brew.plan.stages[i].displayName,
                    '${brew.actualWaterG[i]!.toStringAsFixed(0)} g',
                  ),
            ],
            if (flavorTags.isEmpty &&
                brew.notes.isEmpty &&
                brew.drawdownS == null &&
                !hasWaterReadings)
              Text(
                'Belum ada catatan rasa atau pengukuran tambahan.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
              ),
            // TAMPILAN DETAIL: diagnosa AI jika tersedia.
            if (brew.aiDiagnosis?.text.isNotEmpty == true) ...[
              const SizedBox(height: AppSpace.xxl),
              const Divider(),
              const SizedBox(height: AppSpace.lg),
              Text('DIAGNOSA AI', style: sectionStyle),
              const SizedBox(height: AppSpace.md),
              Text(brew.aiDiagnosis!.text),
              if (brew.aiDiagnosis!.nextPlan != null) ...[
                const SizedBox(height: AppSpace.xxl),
                Text('EKSPERIMEN BERIKUTNYA', style: sectionStyle),
                const SizedBox(height: AppSpace.md),
                Text(brew.aiDiagnosis!.note),
                const SizedBox(height: AppSpace.md),
                detailRow(
                  'Dosis · rasio · suhu',
                  '${brew.aiDiagnosis!.nextPlan!.doseG.toStringAsFixed(1)} g · '
                      '1:${brew.aiDiagnosis!.nextPlan!.ratio.toStringAsFixed(1)} · '
                      '${brew.aiDiagnosis!.nextPlan!.temperatureC} °C',
                ),
                detailRow(
                  'Gilingan · tuangan',
                  '${brew.aiDiagnosis!.nextPlan!.grind} · '
                      '${brew.aiDiagnosis!.nextPlan!.pouringCount} tuangan',
                ),
                const SizedBox(height: AppSpace.md),
                FilledButton.icon(
                  onPressed: beanAvailable
                      ? () => openSetup(
                          brew.aiDiagnosis!.nextPlan!,
                          aiNote: brew.aiDiagnosis!.note,
                        )
                      : null,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Coba saran AI'),
                ),
              ],
              const SizedBox(height: AppSpace.sm),
              Text(
                'Saran, bukan kepastian. Coba dan catat hasilnya.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
            ],
            const SizedBox(height: AppSpace.xxl),
            OutlinedButton.icon(
              onPressed: busy ? null : () => diagnose(brew),
              icon: busy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(
                brew.aiDiagnosis?.text.isNotEmpty != true
                    ? 'Minta diagnosa AI'
                    : 'Minta ulang diagnosa',
              ),
            ),
          ],
        ),
      );
    },
  );
}
