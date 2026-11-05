import '../../../core/location/location_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/formatters.dart';
import '../domain/attendance.dart';

class ApiAttendanceRepository implements AttendanceRepository {
  ApiAttendanceRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<AttendanceDay>> days() async => (await _api.get('/rider/attendance') as Object).mapped(AttendanceDay.fromJson);

  @override
  Future<AttendanceDay?> today() async {
    final now = DateTime.now();
    return (await days()).where((d) => isSameDay(d.checkIn.toLocal(), now)).firstOrNull;
  }

  @override
  Future<void> checkIn(GeoPoint? location) => _api.post('/rider/attendance/check-in', {'location': location?.toJson()});

  @override
  Future<void> checkOut(GeoPoint? location) => _api.post('/rider/attendance/check-out', {'location': location?.toJson()});
}

class ApiEarningsRepository implements EarningsRepository {
  ApiEarningsRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<SalaryMonth>> salaries() async => (await _api.get('/rider/earnings/salaries') as Object).mapped(
    (j) => SalaryMonth(
      month: DateTime.parse(j['month'] as String).toLocal(),
      baseSalary: (j['baseSalary'] as num).toDouble(),
      presentDays: j['presentDays'] as int,
      workingDays: j['workingDays'] as int,
      incentives: (j['incentives'] as num).toDouble(),
      deductions: (j['deductions'] as num).toDouble(),
      paidOn: j['paidOn'] == null ? null : DateTime.parse(j['paidOn'] as String).toLocal(),
    ),
  );

  @override
  Future<List<IncentiveEntry>> incentives() async => (await _api.get('/rider/earnings/incentives') as Object).mapped(
    (j) => IncentiveEntry(title: j['title'] as String, detail: j['detail'] as String, amount: (j['amount'] as num).toDouble(), achieved: j['achieved'] as bool),
  );
}
