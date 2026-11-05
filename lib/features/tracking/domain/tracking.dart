import 'dart:math';

import '../../../core/location/location_service.dart';

class RoutePoint {
  const RoutePoint(this.location, this.at);

  final GeoPoint location;
  final DateTime at;

  Map<String, dynamic> toJson() => {'location': location.toJson(), 'at': at.toIso8601String()};

  factory RoutePoint.fromJson(Map<String, dynamic> j) =>
      RoutePoint(GeoPoint.fromJson(j['location'] as Map<String, dynamic>), DateTime.parse(j['at'] as String));
}

class DutySession {
  const DutySession(this.start, [this.end]);

  final DateTime start;
  final DateTime? end;

  bool get isOpen => end == null;

  Duration duration(DateTime now) => (end ?? now).difference(start);

  Map<String, dynamic> toJson() => {'start': start.toIso8601String(), 'end': end?.toIso8601String()};

  factory DutySession.fromJson(Map<String, dynamic> j) =>
      DutySession(DateTime.parse(j['start'] as String), j['end'] == null ? null : DateTime.parse(j['end'] as String));
}

/// Straight-line distance between two points, in kilometres.
double distanceKm(GeoPoint a, GeoPoint b) {
  const earthRadiusKm = 6371.0;
  double rad(double degrees) => degrees * pi / 180;
  final dLat = rad(b.latitude - a.latitude);
  final dLng = rad(b.longitude - a.longitude);
  final h = pow(sin(dLat / 2), 2) + cos(rad(a.latitude)) * cos(rad(b.latitude)) * pow(sin(dLng / 2), 2);
  return earthRadiusKm * 2 * asin(sqrt(h));
}

/// Total length of a route. GPS jitter under 20 metres doesn't count as movement.
double routeDistanceKm(List<RoutePoint> points) {
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    final step = distanceKm(points[i - 1].location, points[i].location);
    if (step >= 0.02) total += step;
  }
  return total;
}

abstract interface class TrackingRepository {
  /// Oldest first.
  Future<List<RoutePoint>> pointsOn(DateTime day);

  Future<void> addPoint(GeoPoint location);

  /// Newest first.
  Future<List<DutySession>> sessions();

  Future<void> startDuty();

  Future<void> stopDuty();
}
