import 'dart:async';
import '../../../core/network/api_client.dart';
import '../data/api_tracking_repository.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/location/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/contact_launcher.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../attendance/presentation/attendance_screens.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../orders/domain/delivery_order.dart';
import '../../orders/presentation/order_providers.dart';
import '../../pickup/presentation/pickup_screens.dart';
import '../data/fake_tracking_repository.dart';
import '../domain/tracking.dart';

final trackingRepositoryProvider = Provider<TrackingRepository>(
  (ref) => useFakeBackend ? FakeTrackingRepository(ref.watch(riderStoreProvider)) : ApiTrackingRepository(ref.watch(apiProvider)),
);

final todaysRouteProvider = FutureProvider<List<RoutePoint>>(
  (ref) => ref.watch(trackingRepositoryProvider).pointsOn(DateTime.now()),
);

final dutySessionsProvider = FutureProvider<List<DutySession>>(
  (ref) => ref.watch(trackingRepositoryProvider).sessions(),
);

/// Starting duty also checks the rider in if they haven't yet today.
Future<void> setDuty(WidgetRef ref, bool onDuty) async {
  final tracking = ref.read(trackingRepositoryProvider);
  await ref.read(authControllerProvider.notifier).setOnDuty(onDuty);
  if (onDuty) {
    await tracking.startDuty();
    final attendance = ref.read(attendanceRepositoryProvider);
    final today = await attendance.today();
    if (today == null) await attendance.checkIn(await ref.read(locateProvider)());
    ref.invalidate(attendanceProvider);
  } else {
    await tracking.stopDuty();
  }
  ref.invalidate(dutySessionsProvider);
}

/// Records the rider's position while they are on duty and the app is open.
class LocationRecorder extends ConsumerStatefulWidget {
  const LocationRecorder({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LocationRecorder> createState() => _LocationRecorderState();
}

class _LocationRecorderState extends ConsumerState<LocationRecorder> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _record());
  }

  Future<void> _record() async {
    if (!(ref.read(authControllerProvider).value?.onDuty ?? false)) return;
    final location = await ref.read(locateProvider)();
    if (location == null || !mounted) return;
    await ref.read(trackingRepositoryProvider).addPoint(location);
    if (mounted) ref.invalidate(todaysRouteProvider);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

String _hoursAndMinutes(Duration d) => '${d.inHours}h ${d.inMinutes.remainder(60)}m';

class DutyScreen extends ConsumerWidget {
  const DutyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onDuty = ref.watch(authControllerProvider).value?.onDuty ?? false;
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Start / stop duty')),
      body: AsyncBody(
        value: ref.watch(dutySessionsProvider),
        builder: (sessions) {
          final today = sessions.where((s) => isSameDay(s.start, now));
          final total = today.fold(Duration.zero, (sum, s) => sum + s.duration(now));
          return ListView(
            padding: AppSpacing.page,
            children: [
              GradientHeader(
                child: Row(
                  children: [
                    Icon(onDuty ? Icons.delivery_dining : Icons.bedtime_outlined, size: 32, color: AppColors.sky700),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(onDuty ? 'You are on duty' : 'You are off duty', style: text.titleMedium),
                          Text(
                            'Today: ${_hoursAndMinutes(total)}',
                            style: text.bodyMedium?.copyWith(color: AppColors.neutral900),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: onDuty ? FilledButton.styleFrom(backgroundColor: AppColors.red600) : null,
                onPressed: () => setDuty(ref, !onDuty),
                icon: Icon(onDuty ? Icons.stop_circle_outlined : Icons.play_circle_outline),
                label: Text(onDuty ? 'Stop duty' : 'Start duty'),
              ),
              const SizedBox(height: 8),
              Text(
                onDuty
                    ? 'Your location is recorded while the app is open.'
                    : 'Start duty to receive orders and record your route.',
                style: text.bodySmall,
              ),
              const SectionTitle('Duty log'),
              if (sessions.isEmpty) const Text('Your duty times will be listed here.'),
              for (final s in sessions.take(20))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${formatDateShort(s.start)}\n${formatTime(s.start)} - ${s.end == null ? 'now' : formatTime(s.end!)}',
                          ),
                        ),
                        Text(_hoursAndMinutes(s.duration(now)), style: text.labelLarge),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TrailMap extends StatelessWidget {
  const _TrailMap({required this.points, this.current});

  final List<RoutePoint> points;
  final GeoPoint? current;

  LatLng _latLng(GeoPoint p) => LatLng(p.latitude, p.longitude);

  @override
  Widget build(BuildContext context) {
    final coordinates = [for (final p in points) _latLng(p.location), if (current != null) _latLng(current!)];
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        height: 240,
        child: coordinates.isEmpty
            ? const ColoredBox(
                color: AppColors.sky100,
                child: Center(child: Text('Waiting for your location')),
              )
            : FlutterMap(
                options: MapOptions(
                  initialCameraFit: coordinates.length == 1
                      ? null
                      : CameraFit.coordinates(coordinates: coordinates, padding: const EdgeInsets.all(40)),
                  initialCenter: coordinates.last,
                  initialZoom: 15,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'in.iceclubstore.driver_app',
                  ),
                  if (coordinates.length > 1)
                    PolylineLayer(
                      polylines: [Polyline(points: coordinates, strokeWidth: 4, color: AppColors.sky600)],
                    ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: coordinates.last,
                        width: 36,
                        height: 36,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: Icon(Icons.delivery_dining, color: AppColors.sky700, size: 22),
                        ),
                      ),
                    ],
                  ),
                  const Align(
                    alignment: Alignment.bottomRight,
                    child: ColoredBox(
                      color: Colors.white70,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text('© OpenStreetMap contributors', style: TextStyle(fontSize: 10)),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class LiveGpsScreen extends ConsumerStatefulWidget {
  const LiveGpsScreen({super.key});

  @override
  ConsumerState<LiveGpsScreen> createState() => _LiveGpsScreenState();
}

class _LiveGpsScreenState extends ConsumerState<LiveGpsScreen> {
  Timer? _timer;
  GeoPoint? _current;
  DateTime? _updatedAt;
  bool _unavailable = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  Future<void> _refresh() async {
    final location = await ref.read(locateProvider)();
    if (!mounted) return;
    setState(() {
      _unavailable = location == null;
      if (location != null) {
        _current = location;
        _updatedAt = DateTime.now();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onDuty = ref.watch(authControllerProvider).value?.onDuty ?? false;
    final points = ref.watch(todaysRouteProvider).value ?? const <RoutePoint>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Live GPS location')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          if (_unavailable) ...[
            const NoticeBanner(
              'We can\'t read your location. Turn on GPS and allow location for this app.',
              color: AppColors.red600,
            ),
            const SizedBox(height: 10),
          ],
          _TrailMap(points: const [], current: _current),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              children: [
                InfoRow('Status', onDuty ? 'On duty, recording' : 'Off duty, not recording'),
                InfoRow('Current location', _current?.label ?? 'Not available'),
                InfoRow('Last updated', _updatedAt == null ? '-' : formatDateTime(_updatedAt!)),
                InfoRow('Points recorded today', '${points.length}'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const NoticeBanner(
            'Demo: your location stays on this phone and only updates while the app is open. '
            'The company and dealers will see it once the server is connected.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.my_location),
            label: const Text('Update now'),
          ),
        ],
      ),
    );
  }
}

class RouteTrackingScreen extends ConsumerWidget {
  const RouteTrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final factory = ref.watch(factoryProvider).value;
    final orders = ref.watch(ordersProvider).value ?? const <DeliveryOrder>[];
    final now = DateTime.now();
    final stops = orders.where((o) => isSameDay(o.deliveryDate, now)).toList()
      ..sort((a, b) => a.isPending == b.isPending ? 0 : (a.isPending ? 1 : -1));
    final remaining = stops.where((o) => o.isPending).toList();
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Route tracking')),
      body: AsyncBody(
        value: ref.watch(todaysRouteProvider),
        builder: (points) => ListView(
          padding: AppSpacing.page,
          children: [
            _TrailMap(points: points),
            const SizedBox(height: 10),
            AppCard(
              child: Column(
                children: [
                  InfoRow('Distance today', '${routeDistanceKm(points).toStringAsFixed(1)} km'),
                  InfoRow('Stops done', '${stops.length - remaining.length} of ${stops.length}'),
                  if (points.isNotEmpty) InfoRow('Started', formatTime(points.first.at)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: remaining.isEmpty
                  ? null
                  : () => ContactLauncher.navigateRoute([for (final o in remaining) o.address]),
              icon: const Icon(Icons.alt_route),
              label: const Text('Open remaining route in Google Maps'),
            ),
            const SectionTitle('Today\'s stops'),
            if (factory != null)
              _Stop(icon: Icons.factory_outlined, title: factory.name, subtitle: factory.address, done: true),
            if (stops.isEmpty) Text('No stops today.', style: text.bodyMedium),
            for (final o in stops)
              _Stop(
                icon: Icons.storefront,
                title: o.dealerName,
                subtitle: '${o.address}\n${o.slot} · ${o.status.label}',
                done: o.isDone,
              ),
          ],
        ),
      ),
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({required this.icon, required this.title, required this.subtitle, required this.done});

  final IconData icon;
  final String title;
  final String subtitle;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(done ? Icons.check_circle : icon, color: done ? AppColors.green600 : AppColors.sky700),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelLarge),
                  Text(subtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
