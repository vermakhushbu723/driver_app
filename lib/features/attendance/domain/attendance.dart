import '../../../core/location/location_service.dart';

class AttendanceDay {
  const AttendanceDay({required this.checkIn, this.checkOut, this.checkInLocation, this.checkOutLocation});

  final DateTime checkIn;
  final DateTime? checkOut;
  final GeoPoint? checkInLocation;
  final GeoPoint? checkOutLocation;

  Duration workedUntil(DateTime now) => (checkOut ?? now).difference(checkIn);

  AttendanceDay checkedOut(DateTime at, GeoPoint? location) =>
      AttendanceDay(checkIn: checkIn, checkOut: at, checkInLocation: checkInLocation, checkOutLocation: location);

  Map<String, dynamic> toJson() => {
    'checkIn': checkIn.toIso8601String(),
    'checkOut': checkOut?.toIso8601String(),
    'checkInLocation': checkInLocation?.toJson(),
    'checkOutLocation': checkOutLocation?.toJson(),
  };

  factory AttendanceDay.fromJson(Map<String, dynamic> j) => AttendanceDay(
    checkIn: DateTime.parse(j['checkIn'] as String),
    checkOut: j['checkOut'] == null ? null : DateTime.parse(j['checkOut'] as String),
    checkInLocation: j['checkInLocation'] == null
        ? null
        : GeoPoint.fromJson(j['checkInLocation'] as Map<String, dynamic>),
    checkOutLocation: j['checkOutLocation'] == null
        ? null
        : GeoPoint.fromJson(j['checkOutLocation'] as Map<String, dynamic>),
  );
}

class SalaryMonth {
  const SalaryMonth({
    required this.month,
    required this.baseSalary,
    required this.presentDays,
    required this.workingDays,
    required this.incentives,
    this.deductions = 0,
    this.paidOn,
  });

  final DateTime month;
  final double baseSalary;
  final int presentDays;
  final int workingDays;
  final double incentives;
  final double deductions;
  final DateTime? paidOn;

  /// Pay for the days worked, capped at the full monthly salary.
  double get earned {
    final ratio = workingDays == 0 ? 0.0 : presentDays / workingDays;
    return baseSalary * (ratio > 1 ? 1 : ratio);
  }

  double get net => earned + incentives - deductions;
}

class IncentiveEntry {
  const IncentiveEntry({required this.title, required this.detail, required this.amount, this.achieved = true});

  final String title;
  final String detail;
  final double amount;
  final bool achieved;
}

abstract interface class AttendanceRepository {
  /// Newest first.
  Future<List<AttendanceDay>> days();

  Future<AttendanceDay?> today();

  /// Throws if the rider has already checked in today.
  Future<void> checkIn(GeoPoint? location);

  /// Throws if the rider hasn't checked in, or has already checked out.
  Future<void> checkOut(GeoPoint? location);
}

abstract interface class EarningsRepository {
  /// Newest first. The first entry is the month in progress.
  Future<List<SalaryMonth>> salaries();

  Future<List<IncentiveEntry>> incentives();
}
