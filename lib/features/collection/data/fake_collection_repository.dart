import '../../../core/error/app_exception.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/utils/formatters.dart';
import '../../orders/domain/delivery_order.dart';
import '../domain/collection.dart';

class FakeCollectionRepository implements CollectionRepository {
  FakeCollectionRepository(this._store);

  final LocalStore _store;

  static const _entriesKey = 'collections';
  static const _depositsKey = 'deposits';

  List<CollectionEntry> _entries() => (_store.readList(_entriesKey) ?? const []).map(CollectionEntry.fromJson).toList();

  List<CashDeposit> _deposits() => (_store.readList(_depositsKey) ?? const []).map(CashDeposit.fromJson).toList();

  CollectionSummary _summary() => CollectionSummary(
    entries: _entries()..sort((a, b) => b.at.compareTo(a.at)),
    deposits: _deposits()..sort((a, b) => b.at.compareTo(a.at)),
  );

  @override
  Future<CollectionSummary> summary() async {
    await fakeLatency();
    return _summary();
  }

  @override
  Future<void> recordCollection({
    required String orderNumber,
    required String dealerName,
    required double amount,
    required CollectionMode mode,
    required String reference,
    required DateTime at,
  }) => _store.writeList(_entriesKey, [
    for (final e in _entries()) e.toJson(),
    CollectionEntry(
      orderNumber: orderNumber,
      dealerName: dealerName,
      amount: amount,
      mode: mode,
      at: at,
      reference: reference,
    ).toJson(),
  ]);

  @override
  Future<void> depositCash(double amount, String reference) async {
    await fakeLatency();
    final inHand = _summary().cashInHand;
    if (amount > inHand) throw AppException('You only have ${money(inHand)} in hand.');
    await _store.writeList(_depositsKey, [
      for (final d in _deposits()) d.toJson(),
      CashDeposit(amount: amount, at: DateTime.now(), reference: reference).toJson(),
    ]);
  }
}
