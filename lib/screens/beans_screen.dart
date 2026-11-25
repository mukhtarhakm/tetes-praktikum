import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/app_theme.dart';
import '../app/app_ui.dart';
import '../data/models.dart';
import 'brew_screen.dart';
import 'explore_screen.dart';

class BeansScreen extends StatefulWidget {
  const BeansScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<BeansScreen> createState() => _BeansScreenState();
}

class _BeansScreenState extends State<BeansScreen> {
  String search = '';

  Future<void> openForm([Bean? bean]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            BeanFormScreen(controller: widget.controller, bean: bean),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final beans = widget.controller.beans
            .where(
              (bean) => '${bean.name} ${bean.roastery} ${bean.origin}'
                  .toLowerCase()
                  .contains(search.toLowerCase()),
            )
            .toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.xl,
            AppSpace.lg,
            AppSpace.xl,
            AppSpace.xl,
          ),
          children: [
            AppPageHeader(
              title: 'Beans',
              subtitle: '${widget.controller.beans.length} koleksi kopi',
              action: TextButton.icon(
                onPressed: () => openForm(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tambah beans'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.olive,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
            TextField(
              onChanged: (value) => setState(() => search = value),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Cari beans',
              ),
            ),
            const SizedBox(height: AppSpace.xxl),
            if (beans.isEmpty)
              AppStateView(
                icon: Icons.grain_rounded,
                message: widget.controller.beans.isEmpty
                    ? 'Belum ada beans. Tambahkan koleksi pertamamu.'
                    : 'Beans tidak ditemukan.',
                action: widget.controller.beans.isEmpty ? 'Tambah beans' : null,
                onPressed: widget.controller.beans.isEmpty
                    ? () => openForm()
                    : null,
              ),
            for (final bean in beans) ...[
              AppListRow(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BeanDetailScreen(
                      controller: widget.controller,
                      beanId: bean.id,
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
                            bean.name,
                            style: Theme.of(context).textTheme.titleLarge,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (bean.roastery.isNotEmpty ||
                              bean.origin.isNotEmpty)
                            Text(
                              bean.roastery.isEmpty
                                  ? bean.origin
                                  : bean.roastery,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.muted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: AppSpace.sm),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: bean.stockG > 0
                                      ? AppColors.olive
                                      : AppColors.muted,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: AppSpace.sm),
                              Text('Stok ${bean.stockG.toStringAsFixed(0)} g'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
}

class BeanDetailScreen extends StatelessWidget {
  const BeanDetailScreen({
    super.key,
    required this.controller,
    required this.beanId,
  });
  final AppController controller;
  final String beanId;

  String priceText(double value, String currency) {
    final digits = value
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
    return currency == 'IDR' ? 'Rp$digits' : '$currency $digits';
  }

  String roastDateText(String value) {
    final date = DateTime.tryParse(value);
    return date == null ? value : '${date.day}/${date.month}/${date.year}';
  }

  Future<void> deleteBean(BuildContext context, Bean bean) async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus beans?'),
        content: const Text(
          'Beans yang sudah punya riwayat seduh tidak dapat dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (agreed != true || !context.mounted) return;
    try {
      await controller.deleteBean(bean.id);
      if (context.mounted) Navigator.pop(context);
    } catch (error) {
      if (context.mounted) {
        showAppMessage(
          context,
          error is FormatException
              ? error.message
              : 'Beans belum bisa dihapus.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final matches = controller.beans.where((item) => item.id == beanId);
      if (matches.isEmpty) {
        return const Scaffold(
          body: AppStateView(
            icon: Icons.info_outline,
            message: 'Beans tidak ditemukan.',
          ),
        );
      }
      final bean = matches.first;
      final identity = [
        if (bean.roastery.isNotEmpty) bean.roastery,
        if (bean.origin.isNotEmpty) bean.origin,
      ];
      final profile = [
        if (bean.species != null) bean.species!,
        if (bean.beanType != null) bean.beanType!,
      ];
      final processing = [
        if (bean.process != null) bean.processCustom ?? bean.process!,
        if (bean.roastLevel != null) '${bean.roastLevel} roast',
      ];
      final sectionStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
        color: AppColors.muted,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w700,
      );
      void openForm() => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BeanFormScreen(controller: controller, bean: bean),
        ),
      );
      return Scaffold(
        appBar: AppBar(title: const Text('Detail beans')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.xl,
            AppSpace.lg,
            AppSpace.xl,
            AppSpace.section,
          ),
          children: [
            Text(
              bean.name,
              style: AppTheme.coffeeName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (identity.isNotEmpty) ...[
              const SizedBox(height: AppSpace.sm),
              Text(
                identity.join(' · '),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
            const SizedBox(height: AppSpace.lg),
            Row(
              children: [
                const Icon(Icons.circle, size: 9, color: AppColors.olive),
                const SizedBox(width: AppSpace.sm),
                Text(
                  'Stok ${bean.stockG.toStringAsFixed(0)} g',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: AppSpace.xxl),
            const Divider(),
            const SizedBox(height: AppSpace.lg),
            AppButton(
              label: 'Seduh dengan beans ini',
              icon: Icons.play_arrow_rounded,
              onPressed: bean.stockG <= 0
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BrewSetupScreen(
                          controller: controller,
                          initialBeanId: bean.id,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: AppSpace.section),
            const Divider(),
            Row(
              children: [
                Expanded(child: Text('PROFIL BEANS', style: sectionStyle)),
                TextButton(onPressed: openForm, child: const Text('Ubah')),
              ],
            ),
            if (profile.isNotEmpty)
              Text(
                profile.join(' · '),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            if (bean.arabicaPercent != null)
              Text('Arabika ${bean.arabicaPercent}%'),
            if (processing.isNotEmpty)
              Text(
                processing.join(' · '),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            if (bean.roastDate != null)
              Text('Roasting ${roastDateText(bean.roastDate!)}'),
            if (profile.isEmpty && processing.isEmpty && bean.roastDate == null)
              Text(
                'Jenis, proses, dan tanggal roasting belum dicatat.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
              ),
            const SizedBox(height: AppSpace.xxl),
            const Divider(),
            const SizedBox(height: AppSpace.lg),
            Text('RASA', style: sectionStyle),
            const SizedBox(height: AppSpace.md),
            if (bean.tastingTags.isNotEmpty)
              Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.sm,
                children: [
                  for (final tag in bean.tastingTags)
                    Chip(
                      label: Text(tag),
                      backgroundColor: AppColors.background,
                      side: const BorderSide(color: AppColors.olive),
                    ),
                ],
              ),
            if (bean.tastingNotes.isNotEmpty) ...[
              const SizedBox(height: AppSpace.sm),
              Text(bean.tastingNotes),
            ],
            if (bean.tastingTags.isEmpty && bean.tastingNotes.isEmpty)
              Text(
                'Catatan rasa belum ada.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
              ),
            const SizedBox(height: AppSpace.xxl),
            const Divider(),
            const SizedBox(height: AppSpace.lg),
            Text('PEMBELIAN', style: sectionStyle),
            const SizedBox(height: AppSpace.md),
            if (bean.packSizeG != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Kemasan ${bean.packSizeG!.toStringAsFixed(0)} g',
                    ),
                  ),
                  if (bean.packPrice != null)
                    Text(priceText(bean.packPrice!, bean.currency)),
                ],
              ),
            if (bean.price > 0) ...[
              const SizedBox(height: AppSpace.sm),
              Row(
                children: [
                  const Expanded(child: Text('Harga per kg')),
                  Text(priceText(bean.price, bean.currency)),
                ],
              ),
            ],
            if (bean.packSizeG == null && bean.price <= 0)
              Text(
                'Harga belum dicatat.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
              ),
            if (bean.price > 0 && bean.currency != 'IDR') ...[
              const SizedBox(height: AppSpace.md),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FxScreen(
                      controller: controller,
                      initialAmount: bean.price,
                      initialCurrency: bean.currency,
                    ),
                  ),
                ),
                icon: const Icon(Icons.currency_exchange_rounded),
                label: const Text('Lihat harga dalam rupiah'),
              ),
            ],
            const SizedBox(height: AppSpace.xxl),
            TextButton(
              onPressed: () => deleteBean(context, bean),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Hapus beans'),
            ),
          ],
        ),
      );
    },
  );
}

class BeanFormScreen extends StatefulWidget {
  const BeanFormScreen({super.key, required this.controller, this.bean});
  final AppController controller;
  final Bean? bean;

  @override
  State<BeanFormScreen> createState() => _BeanFormScreenState();
}

class _BeanFormScreenState extends State<BeanFormScreen> {
  static const builtInTags = TasteTags.builtIn;

  late final name = TextEditingController(text: widget.bean?.name);
  late final roastery = TextEditingController(text: widget.bean?.roastery);
  late final origin = TextEditingController(text: widget.bean?.origin);
  late final stock = TextEditingController(
    text: widget.bean?.stockG.toString() ?? '250',
  );
  late final packSize = TextEditingController(
    text: widget.bean?.packSizeG?.toString() ?? '',
  );
  late final packPrice = TextEditingController(
    text: widget.bean?.packPrice?.toString() ?? '',
  );
  late final processCustom = TextEditingController(
    text: widget.bean?.processCustom,
  );
  late final tastingNotes = TextEditingController(
    text: widget.bean?.tastingNotes,
  );
  late final customTags = TextEditingController(
    text:
        widget.bean?.tastingTags
            .where((tag) => !builtInTags.contains(tag))
            .join(', ') ??
        '',
  );
  late final selectedTags = <String>{
    ...?widget.bean?.tastingTags.where(builtInTags.contains),
  };
  late String currency = widget.bean?.currency ?? 'IDR';
  late String? species = widget.bean?.species;
  late String? beanType = widget.bean?.beanType;
  late int arabicaPercent = widget.bean?.arabicaPercent ?? 50;
  late bool isSelfRoasted = widget.bean?.isSelfRoasted ?? false;
  late String? process = widget.bean?.process;
  late String? roastLevel = widget.bean?.roastLevel;
  late String? roastDate = widget.bean?.roastDate;
  bool busy = false;

  @override
  void dispose() {
    for (final controller in [
      name,
      roastery,
      origin,
      stock,
      packSize,
      packPrice,
      processCustom,
      tastingNotes,
      customTags,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget choice(
    String label,
    String? value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) => DropdownButtonFormField<String>(
    initialValue: value ?? '',
    decoration: InputDecoration(labelText: label),
    items: ['', ...options]
        .map(
          (item) => DropdownMenuItem(
            value: item,
            child: Text(item.isEmpty ? 'Belum dipilih' : item),
          ),
        )
        .toList(),
    onChanged: (value) => setState(
      () => onChanged(value == null || value.isEmpty ? null : value),
    ),
  );

  Future<void> pickRoastDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(roastDate ?? '') ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (selected != null) {
      setState(() => roastDate = selected.toIso8601String().split('T').first);
    }
  }

  Future<void> save() async {
    final stockG = double.tryParse(stock.text.replaceAll(',', '.'));
    final sizeText = packSize.text.trim().replaceAll(',', '.');
    final priceText = packPrice.text.trim().replaceAll(',', '.');
    final size = sizeText.isEmpty ? null : double.tryParse(sizeText);
    final amount = priceText.isEmpty ? null : double.tryParse(priceText);
    final tags = {
      ...selectedTags,
      ...customTags.text
          .split(',')
          .map((tag) => tag.trim().toLowerCase())
          .where((tag) => tag.isNotEmpty),
    }.toList();
    if (stockG == null ||
        (sizeText.isNotEmpty && size == null) ||
        (priceText.isNotEmpty && amount == null) ||
        (amount != null && size == null) ||
        tags.length > 10 ||
        tags.any((tag) => tag.length > 30)) {
      showAppMessage(
        context,
        'Periksa stok, ukuran kemasan, harga, dan tag rasa (maksimal 10).',
      );
      return;
    }
    final pricePerKg = amount != null && size != null && size > 0
        ? amount * 1000 / size
        : widget.bean?.packPrice == null
        ? widget.bean?.price ?? 0.0
        : 0.0;
    setState(() => busy = true);
    try {
      await widget.controller.saveBean(
        id: widget.bean?.id,
        name: name.text,
        roastery: roastery.text,
        origin: origin.text,
        stockG: stockG,
        price: pricePerKg,
        currency: currency,
        tastingNotes: tastingNotes.text,
        species: species,
        beanType: beanType,
        arabicaPercent: species == 'Campuran' ? arabicaPercent : null,
        isSelfRoasted: isSelfRoasted,
        process: process,
        processCustom: processCustom.text,
        roastLevel: roastLevel,
        roastDate: roastDate,
        packSizeG: size,
        packPrice: amount,
        tastingTags: tags,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        showAppMessage(
          context,
          error is FormatException
              ? error.message
              : 'Biji belum bisa disimpan.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.bean == null ? 'Tambah biji' : 'Ubah biji'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(AppSpace.xl),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Info biji', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpace.md),
              TextField(
                controller: name,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'Nama biji *'),
              ),
              const SizedBox(height: AppSpace.md),
              TextField(
                controller: origin,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Asal biji'),
              ),
              const SizedBox(height: AppSpace.md),
              TextField(
                controller: roastery,
                enabled: !isSelfRoasted,
                decoration: const InputDecoration(labelText: 'Roastery'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Roasting sendiri'),
                value: isSelfRoasted,
                onChanged: (value) => setState(() => isSelfRoasted = value),
              ),
              const SizedBox(height: AppSpace.md),
              choice('Spesies *', species, const [
                'Arabika',
                'Robusta',
                'Campuran',
              ], (value) => species = value),
              const SizedBox(height: AppSpace.md),
              choice('Tipe', beanType, const [
                'Single origin',
                'Blend',
              ], (value) => beanType = value),
              if (species == 'Campuran') ...[
                const SizedBox(height: AppSpace.md),
                Text('Persen arabika: $arabicaPercent%'),
                Slider(
                  value: arabicaPercent.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 100,
                  label: '$arabicaPercent%',
                  onChanged: (value) =>
                      setState(() => arabicaPercent = value.round()),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pengolahan', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpace.md),
              choice('Proses', process, const [
                'Washed',
                'Natural',
                'Honey',
                'Lainnya',
              ], (value) => process = value),
              if (process == 'Lainnya') ...[
                const SizedBox(height: AppSpace.md),
                TextField(
                  controller: processCustom,
                  maxLength: 40,
                  decoration: const InputDecoration(
                    labelText: 'Nama proses lainnya',
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.md),
              choice('Tingkat sangrai', roastLevel, const [
                'Light',
                'Medium',
                'Dark',
              ], (value) => roastLevel = value),
              const SizedBox(height: AppSpace.md),
              OutlinedButton.icon(
                onPressed: pickRoastDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(
                  roastDate == null
                      ? 'Pilih tanggal roasting'
                      : 'Tanggal roasting: $roastDate',
                ),
              ),
              if (roastDate != null)
                TextButton(
                  onPressed: () => setState(() => roastDate = null),
                  child: const Text('Hapus tanggal'),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pembelian', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpace.md),
              TextField(
                controller: packSize,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Ukuran kemasan (g)',
                ),
              ),
              const SizedBox(height: AppSpace.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: packPrice,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Harga kemasan',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: AppCurrencyField(
                      value: currency,
                      onChanged: (value) => setState(() => currency = value),
                    ),
                  ),
                ],
              ),
              if (widget.bean?.packPrice == null &&
                  (widget.bean?.price ?? 0) > 0)
                Text(
                  'Harga lama per kg: ${widget.bean!.currency} ${widget.bean!.price.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: AppSpace.md),
              TextField(
                controller: stock,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Stok awal (g)'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rasa', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpace.md),
              const Text('Tasting notes roastery'),
              Wrap(
                spacing: AppSpace.sm,
                children: [
                  for (final tag in builtInTags)
                    FilterChip(
                      label: Text(tag),
                      selected: selectedTags.contains(tag),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          selectedTags.add(tag);
                        } else {
                          selectedTags.remove(tag);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              TextField(
                controller: customTags,
                decoration: const InputDecoration(
                  labelText: 'Tag sendiri, pisahkan dengan koma',
                ),
              ),
              const SizedBox(height: AppSpace.md),
              TextField(
                controller: tastingNotes,
                maxLines: 3,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Catatan roastery',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xxl),
        AppButton(
          label: 'Simpan biji',
          icon: Icons.save_rounded,
          onPressed: save,
          busy: busy,
        ),
      ],
    ),
  );
}
