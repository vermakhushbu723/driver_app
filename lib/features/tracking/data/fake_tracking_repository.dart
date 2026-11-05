import '../../../core/location/location_service.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/utils/formatters.dart';
import '../domain/tracking.dart';

/// Keeps the route on the phone. In production each point goes to the server,
/// which is what lets the Dealer App show the rider live.
class FakeTrackingRepository implements TrackingRepository {
  FakeTrackingRepository(this._store);

  final LocalStore _store;

  static const _sessionsKey = 'duty_sessions';

  String _pointsKey(DateTime day) => 'route_${dateOnly(day).toIso8601String().substring(0, 10)}';

  List<RoutePoint> _points(DateTime day) =>
      (_store.readList(_pointsKey(day)) ?? const []).map(RoutePoint.fromJson).toList();

  List<DutySession> _sessions() => (_store.readList(_sessionsKey) ?? const []).map(DutySession.fromJson).toList();

  Future<void> _writeSessions(List<DutySession> items) =>
      _store.writeList(_sessionsKey, items.map((s) => s.toJson()).toList());

  @override
  Future<List<RoutePoint>> pointsOn(DateTime day) async => _points(day);

  @override
  Future<void> addPoint(GeoPoint location) {
    final now = DateTime.now();
    return _store.writeList(_pointsKey(now), [
      for (final p in _points(now)) p.toJson(),
      RoutePoint(location, now).toJson(),
    ]);
  }

  @override
  Future<List<DutySession>> sessions() async => _sessions()..sort((a, b) => b.start.compareTo(a.start));

  @override
  Future<void> startDuty() async {
    final items = _sessions();
    if (items.any((s) => s.isOpen)) return;
    await _writeSessions([...items, DutySession(DateTime.now())]);
  }

  @override
  Future<void> stopDuty() {
    final now = DateTime.now();
    return _writeSessions([for (final s in _sessions()) s.isOpen ? DutySession(s.start, now) : s]);
  }
}
