import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app/app_controller.dart';
import '../app/app_theme.dart';
import '../app/app_ui.dart';
import '../data/services.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const weekdays = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];
  bool busy = false;
  BrewReminder? reminder;

  @override
  void initState() {
    super.initState();
    widget.controller
        .savedReminder()
        .then((value) {
          if (mounted) setState(() => reminder = value);
        })
        .catchError((_) {
          if (mounted) showAppMessage(context, 'Pengingat belum bisa dibaca.');
        });
  }

  Future<void> pickPhoto() async {
    setState(() => busy = true);
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (photo == null || !mounted) return;
      await widget.controller.saveProfilePhoto(await photo.readAsBytes());
      if (mounted) showAppMessage(context, 'Foto profil diperbarui.');
    } catch (error) {
      if (mounted) {
        showAppMessage(
          context,
          error is FormatException
              ? error.message
              : 'Foto belum bisa dipilih. Coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pickReminder() async {
    final repeat = await showModalBottomSheet<ReminderRepeat>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Atur pengingat',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            for (final (value, title, subtitle) in [
              (ReminderRepeat.once, 'Sekali', 'Pilih tanggal dan jam'),
              (ReminderRepeat.daily, 'Setiap hari', 'Pada jam yang sama'),
              (
                ReminderRepeat.weekly,
                'Setiap minggu',
                'Pada hari dan jam yang sama',
              ),
            ])
              ListTile(
                title: Text(title),
                subtitle: Text(subtitle),
                trailing: reminder?.repeat == value
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(sheetContext, value),
              ),
          ],
        ),
      ),
    );
    if (repeat == null || !mounted) return;

    DateTime? date;
    int? weekday;
    if (repeat == ReminderRepeat.once) {
      final now = DateTime.now();
      date = await showDatePicker(
        context: context,
        initialDate:
            reminder?.repeat == ReminderRepeat.once &&
                reminder!.when.isAfter(now)
            ? reminder!.when
            : now,
        firstDate: now,
        lastDate: now.add(const Duration(days: 365)),
      );
      if (date == null || !mounted) return;
    } else if (repeat == ReminderRepeat.weekly) {
      weekday = await showDialog<int>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('Pilih hari'),
          children: [
            for (var index = 0; index < weekdays.length; index++)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, index + 1),
                child: Text(weekdays[index]),
              ),
          ],
        ),
      );
      if (weekday == null || !mounted) return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        reminder?.when ?? DateTime.now().add(const Duration(minutes: 5)),
      ),
    );
    if (time == null || !mounted) return;
    final now = DateTime.now();
    final when = repeat == ReminderRepeat.once
        ? DateTime(date!.year, date.month, date.day, time.hour, time.minute)
        : BrewReminder.nextAt(now, time.hour, time.minute, weekday: weekday);
    final selected = BrewReminder(when, repeat);
    setState(() => busy = true);
    try {
      await widget.controller.scheduleReminder(selected);
      if (mounted) {
        setState(() => reminder = selected);
        showAppMessage(context, 'Pengingat seduh dijadwalkan.');
      }
    } catch (error) {
      if (mounted) {
        showAppMessage(
          context,
          error is FormatException
              ? error.message
              : 'Pengingat belum bisa dijadwalkan.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> cancelReminder() async {
    setState(() => busy = true);
    try {
      await widget.controller.cancelReminder();
      if (mounted) {
        setState(() => reminder = null);
        showAppMessage(context, 'Pengingat dimatikan.');
      }
    } catch (_) {
      if (mounted) showAppMessage(context, 'Pengingat belum bisa dimatikan.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String reminderTitle() {
    final saved = reminder;
    if (saved == null) return 'Belum dijadwalkan';
    final time =
        '${saved.when.hour.toString().padLeft(2, '0')}:${saved.when.minute.toString().padLeft(2, '0')}';
    return switch (saved.repeat) {
      ReminderRepeat.once =>
        saved.when.isBefore(DateTime.now())
            ? 'Pengingat selesai'
            : '${saved.when.day}/${saved.when.month}/${saved.when.year} · $time',
      ReminderRepeat.daily => 'Setiap hari · $time',
      ReminderRepeat.weekly =>
        'Setiap ${weekdays[saved.when.weekday - 1]} · $time',
    };
  }

  Future<void> logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Jurnal tetap tersimpan di HP ini untuk akunmu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.controller.logout();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (_) {
      if (mounted) {
        showAppMessage(context, 'Belum bisa keluar. Coba lagi saat online.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.all(AppSpace.xl),
      children: [
        // TAMPILAN PROFIL: foto, email, dan jumlah data akun.
        AppCard(
          color: AppColors.oliveSoft,
          child: Column(
            children: [
              Semantics(
                label: 'Ganti foto profil',
                button: true,
                child: InkWell(
                  onTap: busy ? null : pickPhoto,
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ProfileAvatar(
                            photo: widget.controller.profilePhoto,
                            initial: widget.controller.email ?? 'A',
                            radius: 34,
                          ),
                          const Positioned(
                            right: -4,
                            bottom: -4,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: AppColors.olive,
                              child: Icon(
                                Icons.photo_camera_outlined,
                                size: 14,
                                color: AppColors.surface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: AppSpace.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AKUN',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: AppColors.muted),
                            ),
                            const SizedBox(height: AppSpace.xs),
                            Text(
                              widget.controller.email ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: AppSpace.xs),
                            Text(
                              'Ganti foto',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: AppColors.olive),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.xl),
              const Divider(height: 1),
              const SizedBox(height: AppSpace.lg),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.controller.beans.length} beans',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: AppSpace.xxl,
                    color: AppColors.border,
                  ),
                  const SizedBox(width: AppSpace.lg),
                  Expanded(
                    child: Text(
                      '${widget.controller.brews.length} seduhan',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.section),
        // TAMPILAN PROFIL: jadwal pengingat seduh.
        Text('Pengingat seduh', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpace.md),
        AppCard(
          color: Colors.white,
          child: InkWell(
            onTap: busy ? null : pickReminder,
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.oliveSoft,
                  child: Icon(
                    Icons.notifications_none_rounded,
                    color: AppColors.olive,
                  ),
                ),
                const SizedBox(width: AppSpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminderTitle(),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        reminder == null
                            ? 'Ketuk untuk mengatur pengingat'
                            : 'Ketuk untuk mengubah pengingat',
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
        ),
        if (reminder != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: busy ? null : cancelReminder,
              child: const Text('Matikan pengingat'),
            ),
          ),
        const SizedBox(height: AppSpace.section),
        // TAMPILAN PROFIL: aksi keluar dari akun.
        const Divider(height: 1),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.logout_rounded, color: AppColors.error),
          title: const Text('Keluar akun'),
          textColor: AppColors.error,
          onTap: busy ? null : logout,
        ),
      ],
    ),
  );
}
