import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_controller.dart';
import '../app/app_theme.dart';
import '../app/app_ui.dart';
import '../data/services.dart';

class FxScreen extends StatefulWidget {
  const FxScreen({
    super.key,
    required this.controller,
    this.initialAmount,
    this.initialCurrency,
  });
  final AppController controller;
  final double? initialAmount;
  final String? initialCurrency;

  @override
  State<FxScreen> createState() => _FxScreenState();
}

class _FxScreenState extends State<FxScreen> {
  late final amount = TextEditingController(
    text: widget.initialAmount?.toStringAsFixed(0) ?? '10',
  );
  late String currency = widget.initialCurrency == 'IDR'
      ? 'USD'
      : (widget.initialCurrency ?? 'USD');
  FxQuote? quote;
  double? convertedAmount;
  bool loading = false;
  String? error;

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  Future<void> convert() async {
    final value = double.tryParse(amount.text.replaceAll(',', '.'));
    if (value == null || !value.isFinite || value <= 0) {
      showAppMessage(context, 'Isi harga dengan angka lebih dari nol.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
      quote = null;
      convertedAmount = null;
    });
    final requestedCurrency = currency;
    final requestedAmount = amount.text;
    try {
      final result = await widget.controller.rate(requestedCurrency);
      if (mounted &&
          currency == requestedCurrency &&
          amount.text == requestedAmount) {
        setState(() {
          quote = result;
          convertedAmount = value;
        });
      }
    } catch (_) {
      if (mounted &&
          currency == requestedCurrency &&
          amount.text == requestedAmount) {
        setState(
          () => error =
              'Kurs belum bisa diambil. Periksa internet lalu coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cek kurs')),
    body: ListView(
      padding: const EdgeInsets.all(AppSpace.xl),
      children: [
        Text('Konversi harga beans', style: AppTheme.pageTitle),
        const SizedBox(height: AppSpace.sm),
        Text(
          'Perkirakan harganya dalam rupiah.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: AppSpace.section),
        Text(
          'HARGA ASLI',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.olive,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: amount,
                onChanged: (_) => setState(() {
                  quote = null;
                  convertedAmount = null;
                  error = null;
                }),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Harga beans'),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: AppCurrencyField(
                value: currency,
                includeIdr: false,
                onChanged: (value) => setState(() {
                  currency = value;
                  quote = null;
                  convertedAmount = null;
                  error = null;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.xxl),
        AppButton(label: 'Cek kurs terbaru', onPressed: convert, busy: loading),
        if (error != null) ...[
          const SizedBox(height: AppSpace.xxl),
          Text(
            error!,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          TextButton(onPressed: convert, child: const Text('Coba lagi')),
        ],
        if (quote != null) ...[
          const SizedBox(height: AppSpace.section),
          const Divider(),
          const SizedBox(height: AppSpace.section),
          Text(
            'PERKIRAAN DALAM RUPIAH',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.olive,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpace.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _rupiah(convertedAmount! * quote!.rate),
              style: AppTheme.totalWater.copyWith(color: AppColors.ink),
            ),
          ),
          const SizedBox(height: AppSpace.xxl),
          Text(
            '${_number(convertedAmount!)} ${quote!.currency} × ${_rupiah(quote!.rate, decimals: quote!.rate == quote!.rate.roundToDouble() ? 0 : 2)}',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            quote!.cached
                ? 'Kurs tersimpan · ${_date(quote!.date)}'
                : 'Kurs diperbarui ${_date(quote!.date)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
          if (quote!.cached) ...[
            const SizedBox(height: AppSpace.sm),
            const Text(
              'Kurs terbaru belum tersedia. Hasil ini memakai kurs tersimpan.',
            ),
          ],
          const SizedBox(height: AppSpace.section),
          const Divider(),
          const SizedBox(height: AppSpace.md),
          Text(
            'Harga akhir dapat berbeda saat membeli.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
        ],
      ],
    ),
  );
}

String _number(double value, {int? decimals}) {
  final raw = decimals == null
      ? value.toString().replaceFirst(RegExp(r'\.0$'), '')
      : value.toStringAsFixed(decimals);
  final parts = raw.split('.');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return parts.length == 1 ? whole : '$whole,${parts.last}';
}

String _rupiah(double value, {int decimals = 0}) =>
    'Rp ${_number(value, decimals: decimals)}';

String _date(String iso) {
  final date = DateTime.tryParse(iso);
  if (date == null) return iso;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  late Future<StoreResult> future = widget.controller.nearbyStores();
  final mapController = MapController();
  final sheetController = DraggableScrollableController();
  ScrollController? sheetScrollController;
  StorePlace? selectedPlace;
  StoreRoute? route;
  String? routeError;
  bool routeBusy = false;
  int routeGeneration = 0;

  @override
  void dispose() {
    sheetController.dispose();
    mapController.dispose();
    super.dispose();
  }

  void refresh() => setState(() {
    routeGeneration++;
    selectedPlace = null;
    route = null;
    routeError = null;
    future = widget.controller.nearbyStores();
  });

  void selectPlace(StorePlace place) {
    setState(() {
      routeGeneration++;
      selectedPlace = place;
      route = null;
      routeError = null;
    });
    final zoom = mapController.camera.zoom;
    mapController.move(
      LatLng(place.latitude, place.longitude),
      zoom < 12 ? 12 : zoom,
    );
    if (sheetController.isAttached) {
      sheetController.animateTo(
        0.38,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  String storeType(StorePlace place) =>
      place.type == 'roastery' ? 'Roastery' : 'Toko alat kopi';

  Future<void> loadRoute(StoreResult stores, StorePlace place) async {
    if (routeBusy || stores.latitude == null || stores.longitude == null) {
      return;
    }
    final requestGeneration = routeGeneration;
    setState(() {
      routeBusy = true;
      routeError = null;
    });
    try {
      final loaded = await widget.controller.routeTo(
        stores.latitude!,
        stores.longitude!,
        place,
      );
      if (!mounted || requestGeneration != routeGeneration) return;
      setState(() => route = loaded);
      await sheetScrollController?.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      if (!mounted || requestGeneration != routeGeneration) return;
      mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: loaded.points,
          padding: EdgeInsets.fromLTRB(
            AppSpace.section,
            100,
            AppSpace.section,
            MediaQuery.sizeOf(context).height * 0.38,
          ),
          maxZoom: 14,
        ),
      );
    } catch (_) {
      if (mounted && requestGeneration == routeGeneration) {
        setState(
          () => routeError = 'Rute belum bisa dimuat. Coba lagi saat online.',
        );
      }
    } finally {
      if (mounted) setState(() => routeBusy = false);
    }
  }

  String routeDistance(double meters) => meters < 1000
      ? '${meters.round()} m lewat jalan'
      : '${(meters / 1000).toStringAsFixed(1)} km lewat jalan';

  String routeDuration(double seconds) {
    final minutes = (seconds / 60).ceil();
    if (minutes < 60) return '±$minutes menit berkendara';
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return remainder == 0
        ? '±$hours jam berkendara'
        : '±$hours jam $remainder menit berkendara';
  }

  Widget fallback(Widget content) => SafeArea(
    child: Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Kembali',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Text('Tempat kopi', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            IconButton(
              tooltip: 'Perbarui lokasi',
              onPressed: refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        Expanded(child: content),
      ],
    ),
  );

  Future<void> openNavigation(StorePlace place) async {
    final destination = '${place.latitude},${place.longitude}';
    final appUri = Uri.parse('google.navigation:q=$destination');
    final webUri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
    });

    try {
      if (await launchUrl(appUri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}

    try {
      if (await launchUrl(webUri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}

    if (mounted) {
      showAppMessage(
        context,
        'Tidak ada aplikasi peta yang dapat membuka navigasi.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: FutureBuilder<StoreResult>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return fallback(const Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return fallback(
            AppStateView(
              icon: Icons.error_outline_rounded,
              message: 'Daftar tempat belum bisa dibuka.',
              action: 'Coba lagi',
              onPressed: refresh,
            ),
          );
        }
        final result = snapshot.data!;
        if (result.places.isEmpty) {
          return fallback(
            const AppStateView(
              icon: Icons.store_outlined,
              message: 'Belum ada roastery atau toko alat kopi.',
            ),
          );
        }
        final locationAvailable =
            result.latitude != null && result.longitude != null;
        final selected = result.places.contains(selectedPlace)
            ? selectedPlace!
            : result.places.first;
        final distance = result.distanceTo(selected);
        return LayoutBuilder(
          builder: (context, size) => Stack(
            children: [
              FlutterMap(
                key: ObjectKey(result),
                mapController: mapController,
                options: MapOptions(
                  initialCenter: LatLng(
                    result.places.first.latitude,
                    result.places.first.longitude,
                  ),
                  initialZoom: 11,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.raismukhtar.tetes_praktikum',
                  ),
                  if (route != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: route!.points,
                          strokeWidth: 5,
                          color: AppColors.terracotta,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (locationAvailable)
                        Marker(
                          point: LatLng(result.latitude!, result.longitude!),
                          width: 36,
                          height: 36,
                          child: const Icon(
                            Icons.person_pin_circle_rounded,
                            color: AppColors.ink,
                            size: 32,
                          ),
                        ),
                      for (final place in result.places)
                        Marker(
                          point: LatLng(place.latitude, place.longitude),
                          width: 44,
                          height: 44,
                          child: Semantics(
                            label: place.name,
                            button: true,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => selectPlace(place),
                              child: Icon(
                                Icons.location_on_rounded,
                                color: place == selected
                                    ? AppColors.ink
                                    : AppColors.olive,
                                size: place == selected ? 38 : 30,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + AppSpace.sm,
                left: AppSpace.xl,
                right: AppSpace.xl,
                child: Material(
                  color: AppColors.surface,
                  elevation: 4,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Kembali',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      Expanded(
                        child: Text(
                          'Tempat kopi',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Perbarui lokasi',
                        onPressed: refresh,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: AppSpace.xl,
                bottom: size.maxHeight * 0.38 + AppSpace.md,
                child: FloatingActionButton.small(
                  heroTag: 'store_location',
                  tooltip: 'Lokasiku',
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.ink,
                  onPressed: () {
                    if (!locationAvailable) {
                      showAppMessage(context, 'Lokasimu belum tersedia.');
                      return;
                    }
                    mapController.move(
                      LatLng(result.latitude!, result.longitude!),
                      13,
                    );
                  },
                  child: const Icon(Icons.my_location_rounded),
                ),
              ),
              Positioned(
                left: AppSpace.sm,
                bottom: size.maxHeight * 0.38 + AppSpace.xs,
                child: ColoredBox(
                  color: AppColors.surface,
                  child: Text(
                    '© OpenStreetMap contributors',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              DraggableScrollableSheet(
                controller: sheetController,
                initialChildSize: 0.38,
                minChildSize: 0.27,
                maxChildSize: 0.82,
                snap: true,
                snapSizes: const [0.38, 0.82],
                builder: (context, scrollController) {
                  sheetScrollController = scrollController;
                  return Material(
                    color: AppColors.surface,
                    elevation: 12,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.card),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.xl,
                        AppSpace.sm,
                        AppSpace.xl,
                        AppSpace.section,
                      ),
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpace.lg),
                        Text(
                          '${result.places.length} tempat tersedia',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          'Roastery dan toko alat kopi',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.muted),
                        ),
                        if (result.message != null) ...[
                          const SizedBox(height: AppSpace.sm),
                          Text(
                            result.message!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: AppSpace.md),
                        const Divider(),
                        const SizedBox(height: AppSpace.sm),
                        Text(
                          selected.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          storeType(selected),
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: AppColors.olive),
                        ),
                        Text(
                          selected.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppSpace.sm),
                        Text(
                          route != null
                              ? routeDistance(route!.distanceM)
                              : distance == null
                              ? 'Jarak belum tersedia'
                              : '${(distance / 1000).toStringAsFixed(1)} km garis lurus',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: AppColors.olive),
                        ),
                        if (route != null) ...[
                          Text(
                            routeDuration(route!.durationS),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            'Rute OSRM · data OpenStreetMap',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.muted),
                          ),
                        ],
                        if (routeError != null)
                          Text(
                            routeError!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.error),
                          ),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              onPressed: locationAvailable && !routeBusy
                                  ? () => loadRoute(result, selected)
                                  : null,
                              icon: routeBusy
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.route_rounded),
                              label: Text(
                                routeBusy
                                    ? 'Menghitung...'
                                    : route == null
                                    ? 'Lihat rute'
                                    : 'Perbarui rute',
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => openNavigation(selected),
                              icon: const Icon(Icons.directions_rounded),
                              label: const Text('Navigasi'),
                            ),
                          ],
                        ),
                        const Divider(),
                        const SizedBox(height: AppSpace.sm),
                        Text(
                          'Semua tempat',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        for (final place in result.places) ...[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(place.name),
                            subtitle: Text(storeType(place)),
                            selected: place == selected,
                            selectedColor: AppColors.olive,
                            onTap: () => selectPlace(place),
                          ),
                          const Divider(height: 1),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    ),
  );
}
