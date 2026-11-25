import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/app_theme.dart';
import '../app/app_ui.dart';
import '../data/models.dart';
import 'beans_screen.dart';
import 'brew_screen.dart';
import 'explore_screen.dart';
import 'journal_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;

  void open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  void openProfile() => open(
    Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ProfileScreen(controller: widget.controller),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: IndexedStack(
        index: tab,
        children: [
          _Dashboard(
            controller: widget.controller,
            open: open,
            openBeans: () => setState(() => tab = 1),
            openProfile: openProfile,
          ),
          BeansScreen(controller: widget.controller),
          JournalScreen(controller: widget.controller),
          _MoreScreen(
            controller: widget.controller,
            open: open,
            openProfile: openProfile,
          ),
        ],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      backgroundColor: AppColors.background,
      indicatorColor: AppColors.oliveSoft,
      onDestinationSelected: (value) => setState(() => tab = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Beranda',
        ),
        NavigationDestination(
          icon: Icon(Icons.coffee_outlined),
          selectedIcon: Icon(Icons.coffee_rounded),
          label: 'Beans',
        ),
        NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          selectedIcon: Icon(Icons.menu_book_rounded),
          label: 'Jurnal',
        ),
        NavigationDestination(
          icon: Icon(Icons.more_horiz_rounded),
          label: 'Lainnya',
        ),
      ],
    ),
  );
}

class _Dashboard extends StatefulWidget {
  const _Dashboard({
    required this.controller,
    required this.open,
    required this.openBeans,
    required this.openProfile,
  });
  final AppController controller;
  final void Function(Widget) open;
  final VoidCallback openBeans;
  final VoidCallback openProfile;

  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  String? selectedBeanId;

  Bean? get selectedBean {
    final beans = widget.controller.beans;
    if (beans.isEmpty) return null;
    for (final bean in beans) {
      if (bean.id == selectedBeanId) return bean;
    }
    for (final bean in beans) {
      if (bean.stockG > 0) return bean;
    }
    return beans.first;
  }

  Future<void> chooseBean() async {
    final chosenId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.65,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.xl,
                  0,
                  AppSpace.xl,
                  AppSpace.md,
                ),
                child: Text(
                  'Pilih beans',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              for (final bean in widget.controller.beans)
                ListTile(
                  title: Text(bean.name),
                  subtitle: Text('Stok ${bean.stockG.toStringAsFixed(0)} g'),
                  trailing: bean.id == selectedBean?.id
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.pop(sheetContext, bean.id),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosenId != null && mounted) setState(() => selectedBeanId = chosenId);
  }

  String lastBrewDate(DateTime value) {
    final day = DateUtils.dateOnly(value.toLocal());
    final today = DateUtils.dateOnly(DateTime.now());
    if (day == today) return 'Hari ini';
    if (day == today.subtract(const Duration(days: 1))) return 'Kemarin';
    return '${day.day}/${day.month}/${day.year}';
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final bean = selectedBean;
      final latest = widget.controller.brews.isEmpty
          ? null
          : widget.controller.brews.first;
      final beanProfile = [
        if (bean?.species != null) bean!.species!,
        if (bean?.process != null) bean!.process!,
      ].join(' · ');
      return ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.xl,
          AppSpace.lg,
          AppSpace.xl,
          AppSpace.section,
        ),
        children: [
          Row(
            children: [
              Text('tetes.', style: AppTheme.wordmark),
              const Spacer(),
              IconButton(
                tooltip: 'Profil',
                onPressed: widget.openProfile,
                icon: ProfileAvatar(
                  photo: widget.controller.profilePhoto,
                  initial: widget.controller.email ?? 'A',
                  radius: 18,
                ),
              ),
            ],
          ),
          const Divider(height: AppSpace.section),
          const SizedBox(height: AppSpace.section),
          Text(
            bean == null ? 'MULAI DARI SINI' : 'UNTUK SEDUH BERIKUTNYA',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(letterSpacing: 1.5),
          ),
          const SizedBox(height: AppSpace.lg),
          Text(
            bean?.name ?? 'Pilih beans pertamamu',
            style: AppTheme.coffeeName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpace.sm),
          if (bean != null) ...[
            Text(
              beanProfile.isNotEmpty
                  ? beanProfile
                  : (bean.origin.isEmpty ? 'Siap untuk diseduh' : bean.origin),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              bean.stockG > 0
                  ? 'Stok ${bean.stockG.toStringAsFixed(0)} g'
                  : 'Stok habis',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSpace.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: chooseBean,
                label: const Text('Ganti beans'),
                icon: const Icon(Icons.chevron_right_rounded),
                iconAlignment: IconAlignment.end,
              ),
            ),
          ] else
            Text(
              'Tambahkan kopi yang kamu punya untuk mulai mencatat seduhan.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
            ),
          const SizedBox(height: AppSpace.section),
          AppButton(
            label: bean == null ? 'Tambah beans' : 'Mulai seduh',
            icon: Icons.arrow_forward_rounded,
            trailingIcon: true,
            onPressed: bean == null
                ? widget.openBeans
                : bean.stockG <= 0
                ? null
                : () => widget.open(
                    BrewSetupScreen(
                      controller: widget.controller,
                      initialBeanId: bean.id,
                    ),
                  ),
          ),
          const SizedBox(height: AppSpace.section),
          const SizedBox(height: AppSpace.section),
          const Divider(),
          const SizedBox(height: AppSpace.lg),
          Text(
            'SEDUHAN TERAKHIR',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(letterSpacing: 1.5),
          ),
          const SizedBox(height: AppSpace.lg),
          if (latest == null)
            Text(
              'Seduhan pertamamu akan tercatat di sini.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
            )
          else
            AppListRow(
              onTap: () => widget.open(
                BrewDetailScreen(
                  controller: widget.controller,
                  brewId: latest.id,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          latest.plan.beanName,
                          style: Theme.of(context).textTheme.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${lastBrewDate(latest.brewedAt)} · ${latest.plan.doseG.toStringAsFixed(0)} g · 1:${latest.plan.ratio.toStringAsFixed(1)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  Text('${latest.score}/5'),
                  const SizedBox(width: AppSpace.sm),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
        ],
      );
    },
  );
}

class _MoreScreen extends StatelessWidget {
  const _MoreScreen({
    required this.controller,
    required this.open,
    required this.openProfile,
  });
  final AppController controller;
  final void Function(Widget) open;
  final VoidCallback openProfile;

  Widget toolRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) => AppListRow(
    onTap: onTap,
    child: Row(
      children: [
        Icon(icon, color: AppColors.olive),
        const SizedBox(width: AppSpace.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final accountName = controller.email?.split('@').first;
      final name = accountName?.isNotEmpty == true ? accountName! : 'Akun';
      return ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.xl,
          AppSpace.lg,
          AppSpace.xl,
          AppSpace.xl,
        ),
        children: [
          const AppPageHeader(title: 'Lainnya', subtitle: 'Akun dan peralatan'),
          AppListRow(
            onTap: openProfile,
            child: Row(
              children: [
                ProfileAvatar(
                  photo: controller.profilePhoto,
                  initial: name,
                  radius: 20,
                ),
                const SizedBox(width: AppSpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Kelola akun dan pengingat',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.section),
          Text(
            'PERALATAN',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.muted,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpace.md),
          toolRow(
            context,
            icon: Icons.currency_exchange_rounded,
            title: 'Cek kurs',
            subtitle: 'Konversi harga kopi',
            onTap: () => open(FxScreen(controller: controller)),
          ),
          toolRow(
            context,
            icon: Icons.map_outlined,
            title: 'Tempat kopi',
            subtitle: 'Roastery dan toko alat kopi',
            onTap: () => open(StoreScreen(controller: controller)),
          ),
        ],
      );
    },
  );
}
