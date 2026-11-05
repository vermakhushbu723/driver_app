import '../../../core/location/location_service.dart';
import '../../../core/network/api_client.dart';
import '../domain/tracking.dart';

/// Each point also becomes the rider's live position on the buyer's map and in the admin panel.
class ApiTrackingRepository implements TrackingRepository {
  ApiTrackingRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<RoutePoint>> pointsOn(DateTime day) async {
    final key = day.toIso8601String().substring(0, 10);
    return (await _api.get('/rider/tracking/points?day=$key') as Object).mapped(RoutePoint.fromJson);
  }

  @override
  Future<void> addPoint(GeoPoint location) => _api.post('/rider/tracking/points', {'location': location.toJson()});

  @override
  Future<List<DutySession>> sessions() async => (await _api.get('/rider/tracking/sessions') as Object).mapped(DutySession.fromJson);

  @override
  Future<void> startDuty() => _api.post('/rider/tracking/start');

  @override
  Future<void> stopDuty() => _api.post('/rider/tracking/stop');
}
