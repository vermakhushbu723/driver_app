import '../../../core/network/api_client.dart';
import '../../../core/widgets/photo_field.dart';
import '../domain/delivery_order.dart';

class ApiOrderRepository implements OrderRepository {
  ApiOrderRepository(this._api);

  final ApiClient _api;

  Future<List<Map<String, dynamic>>> _uploaded(List<CapturedPhoto> photos) async => [
    for (final p in photos) CapturedPhoto(await _api.upload(p.path), p.takenAt).toJson(),
  ];

  @override
  Future<List<DeliveryOrder>> orders() async => (await _api.get('/rider/orders') as Object).mapped(DeliveryOrder.fromJson);

  @override
  Future<void> accept(String orderId) => _api.post('/rider/orders/$orderId/accept');

  @override
  Future<void> reject(String orderId, String reason) => _api.post('/rider/orders/$orderId/reject', {'reason': reason});

  @override
  Future<void> confirmPickup(String orderId, PickupRecord pickup) async =>
      _api.post('/rider/orders/$orderId/pickup', {...pickup.toJson(), 'photos': await _uploaded(pickup.photos)});

  @override
  Future<void> startDelivery(String orderId) => _api.post('/rider/orders/$orderId/start');

  @override
  Future<void> completeDelivery(String orderId, String otp, DeliveryRecord delivery) async =>
      _api.post('/rider/orders/$orderId/complete', {...delivery.toJson(), 'otp': otp, 'photos': await _uploaded(delivery.photos)});

  @override
  Future<void> updateDelivery(String orderId, DeliveryRecord delivery) async =>
      _api.patch('/rider/orders/$orderId/delivery', {'receivedBy': delivery.receivedBy, 'photos': await _uploaded(delivery.photos)});

  @override
  Future<void> markFailed(String orderId, FailureRecord failure) async =>
      _api.post('/rider/orders/$orderId/fail', {...failure.toJson(), 'photos': await _uploaded(failure.photos)});
}
