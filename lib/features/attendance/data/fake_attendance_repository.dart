import '../../../core/error/app_exception.dart';
import '../../../core/location/location_service.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/utils/formatters.dart';
import '../../orders/domain/delivery_order.dart';
import '../domain/attendance.dart';

class FakeAttendanceRepository implements AttendanceRepository {
  FakeAttendanceRepository(this._store);

  final LocalStore _store;

  static const _key = 'attendance';

  List<AttendanceDay> _read() => (_store.readList(_key) ?? const []).map(AttendanceDay.fromJson).toList();

  Future<void> _write(List<AttendanceDay> items) => _store.writeList(_key, items.map((d) => d.toJson()).toList());

  @override
  Future<List<AttendanceDay>> days() async => _read()..sort((a, b) => b.checkIn.compareTo(a.checkIn));

  @override
  Future<AttendanceDay?> today() async {
    final now = DateTime.now();
    return _read().where((d) => isSameDay(d.checkIn, now)).firstOrNull;
  }

  @override
  Future<void> checkIn(GeoPoint? location) async {
    if (await today() != null) throw const AppException('You have already checked in today.');
    await _write([..._read(), AttendanceDay(checkIn: DateTime.now(), checkInLocation: location)]);
  }

  @override
  Future<void> checkOut(GeoPoint? location) async {
    final current = await today();
    if (current == null) throw const AppException('Please check in first.');
    if (current.checkOut != null) throw const AppException('You have already checked out today.');
    final now = DateTime.now();
    await _write([for (final d in _read()) isSameDay(d.checkIn, now) ? d.checkedOut(now, location) : d]);
  }
}

/// Sample pay rules until the Admin Panel holds each rider's real figures.
class FakeEarningsRepository implements EarningsRepository {
  FakeEarningsRepository(this._attendance, this._orders);

  final AttendanceRepository _attendance;
  final OrderRepository _orders;

  static const _baseSalary = 18000.0;
  static const _workingDays = 26;
  static const _perDelivery = 10.0;
  static const _monthlyTarget = 100;
  static const _targetBonus = 500.0;

  Future<int> _deliveredThisMonth() async {
    final now = DateTime.now();
    final orders = await _orders.orders();
    return orders.where((o) {
      final at = o.delivery?.at;
      return at != null && at.year == now.year && at.month == now.month;
    }).length;
  }

  double _incentiveFor(int delivered) => delivered * _perDelivery + (delivered >= _monthlyTarget ? _targetBonus : 0);

  @override
  Future<List<SalaryMonth>> salaries() async {
    final now = DateTime.now();
    final days = await _attendance.days();
    final present = days.where((d) => d.checkIn.year == now.year && d.checkIn.month == now.month).length;
    final delivered = await _deliveredThisMonth();
    return [
      SalaryMonth(
        month: DateTime(now.year, now.month),
        baseSalary: _baseSalary,
        presentDays: present,
        workingDays: _workingDays,
        incentives: _incentiveFor(delivered),
      ),
      for (var i = 1; i <= 3; i++)
        SalaryMonth(
          month: DateTime(now.year, now.month - i),
          baseSalary: _baseSalary,
          presentDays: 25,
          workingDays: _workingDays,
          incentives: 1200,
          deductions: 200,
          paidOn: DateTime(now.year, now.month - i + 1, 5),
        ),
    ];
  }

  @override
  Future<List<IncentiveEntry>> incentives() async {
    final delivered = await _deliveredThisMonth();
    return [
      IncentiveEntry(
        title: 'Per delivery',
        detail: '$delivered ${delivered == 1 ? 'delivery' : 'deliveries'} this month at ${money(_perDelivery)} each',
        amount: delivered * _perDelivery,
      ),
      IncentiveEntry(
        title: 'Monthly target',
        detail: '$delivered of $_monthlyTarget deliveries',
        amount: _targetBonus,
        achieved: delivered >= _monthlyTarget,
      ),
    ];
  }
}
