import '../../../core/network/api_client.dart';
import '../../orders/domain/delivery_order.dart';
import '../domain/collection.dart';

/// Money collected is recorded by the server when a delivery is completed.
class ApiCollectionRepository implements CollectionRepository {
  ApiCollectionRepository(this._api);

  final ApiClient _api;

  @override
  Future<CollectionSummary> summary() async {
    final j = await _api.get('/rider/collections') as Map<String, dynamic>;
    return CollectionSummary(entries: (j['entries'] as Object).mapped(CollectionEntry.fromJson), deposits: (j['deposits'] as Object).mapped(CashDeposit.fromJson));
  }

  @override
  Future<void> recordCollection({
    required String orderNumber,
    required String dealerName,
    required double amount,
    required CollectionMode mode,
    required String reference,
    required DateTime at,
  }) async {}

  @override
  Future<void> depositCash(double amount, String reference) => _api.post('/rider/collections/deposits', {'amount': amount, 'reference': reference});
}
