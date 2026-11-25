import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/currencies.dart';
import 'app_theme.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.photo,
    required this.initial,
    required this.radius,
  });

  final Uint8List? photo;
  final String initial;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fallback = Text(
      initial.isEmpty ? 'A' : initial[0].toUpperCase(),
      style: Theme.of(context).textTheme.titleLarge,
    );
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.oliveSoft,
      child: photo == null
          ? fallback
          : ClipOval(
              child: Image.memory(
                photo!,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
            ),
    );
  }
}

class AppCurrencyField extends StatelessWidget {
  const AppCurrencyField({
    super.key,
    required this.value,
    required this.onChanged,
    this.includeIdr = true,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool includeIdr;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(AppRadius.field),
    onTap: () async {
      final selected = await showSearch<String>(
        context: context,
        delegate: _CurrencySearch(value, includeIdr),
      );
      if (selected != null && selected != value) onChanged(selected);
    },
    child: InputDecorator(
      decoration: const InputDecoration(labelText: 'Mata uang'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(child: Text(value)),
          const Icon(Icons.expand_more_rounded),
        ],
      ),
    ),
  );
}

class _CurrencySearch extends SearchDelegate<String> {
  _CurrencySearch(this.selected, this.includeIdr)
    : super(searchFieldLabel: 'Cari kode atau nama mata uang');

  final String selected;
  final bool includeIdr;

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        tooltip: 'Hapus pencarian',
        onPressed: () => query = '',
        icon: const Icon(Icons.close_rounded),
      ),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    tooltip: 'Kembali',
    onPressed: () => close(context, selected),
    icon: const Icon(Icons.arrow_back_rounded),
  );

  @override
  Widget buildResults(BuildContext context) => _list(context);

  @override
  Widget buildSuggestions(BuildContext context) => _list(context);

  Widget _list(BuildContext context) {
    final term = query.trim().toLowerCase();
    final entries = currencyNames.entries
        .where(
          (entry) =>
              (includeIdr || entry.key != 'IDR') &&
              (entry.key.toLowerCase().contains(term) ||
                  entry.value.toLowerCase().contains(term)),
        )
        .toList();
    if (entries.isEmpty) {
      return const AppStateView(
        icon: Icons.search_off_rounded,
        message: 'Mata uang tidak ditemukan.',
      );
    }
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return ListTile(
          title: Text(entry.key),
          subtitle: Text(entry.value),
          trailing: entry.key == selected
              ? const Icon(Icons.check_rounded, color: AppColors.olive)
              : null,
          onTap: () => close(context, entry.key),
        );
      },
    );
  }
}

class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: AppTheme.pageTitle),
      const SizedBox(height: AppSpace.xs),
      Text(
        subtitle,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
      ),
      const SizedBox(height: AppSpace.lg),
      const Divider(height: 1, color: AppColors.border),
      const SizedBox(height: AppSpace.md),
      ?action,
      const SizedBox(height: AppSpace.md),
    ],
  );
}

class AppListRow extends StatelessWidget {
  const AppListRow({super.key, required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
          child: child,
        ),
      ),
      const Divider(height: 1),
    ],
  );
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.color = AppColors.surface,
  });

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpace.xl),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AppRadius.card),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0F000000),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.trailingIcon = false,
    this.color = AppColors.olive,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final bool trailingIcon;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
      ),
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon ?? Icons.arrow_forward_rounded),
      label: Text(label),
      iconAlignment: trailingIcon ? IconAlignment.end : IconAlignment.start,
    ),
  );
}

class AppStateView extends StatelessWidget {
  const AppStateView({
    super.key,
    required this.icon,
    required this.message,
    this.action,
    this.onPressed,
  });

  final IconData icon;
  final String message;
  final String? action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.oliveSoft,
            child: Icon(icon, color: AppColors.ink),
          ),
          const SizedBox(height: AppSpace.lg),
          Text(message, textAlign: TextAlign.center),
          if (action != null && onPressed != null) ...[
            const SizedBox(height: AppSpace.lg),
            TextButton(onPressed: onPressed, child: Text(action!)),
          ],
        ],
      ),
    ),
  );
}

void showAppMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
