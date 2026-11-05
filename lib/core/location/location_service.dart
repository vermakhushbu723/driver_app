import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  String get label => '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  Map<String, dynamic> toJson() => {'latitude': latitude, 'longitude': longitude};

  factory GeoPoint.fromJson(Map<String, dynamic> j) =>
      GeoPoint((j['latitude'] as num).toDouble(), (j['longitude'] as num).toDouble());
}

Future<GeoPoint?> _currentLocation() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return null;
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
    );
    return GeoPoint(position.latitude, position.longitude);
  } catch (_) {
    return null;
  }
}

/// The rider's position, or null when it can't be read. A rider in a basement
/// or with no signal must still be able to finish the job, so this never throws.
final locateProvider = Provider<Future<GeoPoint?> Function()>((ref) => _currentLocation);
