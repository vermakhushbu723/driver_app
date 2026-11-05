import '../../../core/storage/local_store.dart';
import '../../notifications/domain/notification.dart';
import '../domain/return_report.dart';

class FakeReturnRepository implements ReturnRepository {
  FakeReturnRepository(this._store, this._notifications);

  final LocalStore _store;
  final NotificationRepository _notifications;

  static const _key = 'return_reports';

  List<ReturnReport> _read() => (_store.readList(_key) ?? const []).map(ReturnReport.fromJson).toList();

  @override
  Future<List<ReturnReport>> reports() async {
    await fakeLatency();
    return _read()..sort((a, b) => b.at.compareTo(a.at));
  }

  @override
  Future<void> submit(ReturnReport report) async {
    await fakeLatency();
    await _store.writeList(_key, [
      for (final r in [..._read(), report]) r.toJson(),
    ]);
    await _notifications.add(
      NotificationType.order,
      '${report.type.label} reported',
      '${report.quantity} units on ${report.orderNumber}. Bring the stock back to the factory.',
    );
  }
}
