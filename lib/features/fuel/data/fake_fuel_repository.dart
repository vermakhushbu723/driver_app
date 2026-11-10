import '../../../core/storage/local_store.dart';
import '../domain/fuel_top_up.dart';

/// Keeps top-ups on the device, for the demo build without a server.
class FakeFuelRepository implements FuelRepository {
  FakeFuelRepository(this._store);

  final LocalStore _store;

  static const _key = 'fuel_top_ups';

  List<FuelTopUp> _read() => (_store.readList(_key) ?? const []).map(FuelTopUp.fromJson).toList();

  @override
  Future<FuelAccount> account() async {
    await fakeLatency();
    final list = _read()..sort((a, b) => b.at.compareTo(a.at));
    final now = DateTime.now();
    final month = list.where((f) => f.at.year == now.year && f.at.month == now.month && f.status != FuelStatus.rejected);
    return FuelAccount(list, FuelMonth(amount: month.fold(0, (s, f) => s + f.amount), litres: month.fold(0, (s, f) => s + f.litres), count: month.length));
  }

  @override
  Future<FuelTopUp> send(NewFuelTopUp topUp) async {
    await fakeLatency();
    final saved = FuelTopUp(
      id: 'FU-${DateTime.now().millisecondsSinceEpoch}',
      amount: topUp.amount,
      litres: topUp.litres,
      odometerKm: topUp.odometerKm,
      pump: topUp.pump,
      note: topUp.note,
      video: topUp.videoPath,
      at: DateTime.now(),
      status: FuelStatus.pending,
    );
    await _store.writeList(_key, [..._read(), saved].map((f) => f.toJson()).toList());
    return saved;
  }
}
