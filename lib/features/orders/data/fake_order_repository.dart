import '../../../core/error/app_exception.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/utils/formatters.dart';
import '../../collection/domain/collection.dart';
import '../../notifications/domain/notification.dart';
import '../domain/delivery_order.dart';

const _cube = OrderItem(id: 'cube-20', name: 'Cube Ice', packSize: '20 kg bag', unit: 'bag', quantity: 12, rate: 348);
const _tube = OrderItem(id: 'tube-20', name: 'Tube Ice', packSize: '20 kg bag', unit: 'bag', quantity: 8, rate: 330);
const _block = OrderItem(
  id: 'block-50',
  name: 'Block Ice',
  packSize: '50 kg block',
  unit: 'block',
  quantity: 10,
  rate: 378,
);

/// Keeps a rider's orders on the device. Sample dealers and orders are added
/// for each new day until the Admin Panel can assign real ones.
class FakeOrderRepository implements OrderRepository {
  FakeOrderRepository(this._store, this._collections, this._notifications);

  final LocalStore _store;
  final CollectionRepository _collections;
  final NotificationRepository _notifications;

  static const _key = 'orders';
  static const _seedDateKey = 'seed_date';

  List<DeliveryOrder> _read() => (_store.readList(_key) ?? const []).map(DeliveryOrder.fromJson).toList();

  Future<void> _write(List<DeliveryOrder> items) => _store.writeList(_key, items.map((o) => o.toJson()).toList());

  DeliveryOrder _sample(
    String id,
    DateTime day,
    String dealer,
    String address,
    List<OrderItem> items,
    PaymentType payment,
    String slot,
    String otp, {
    List<StatusEvent>? events,
    DeliveryRecord? delivery,
    FailureRecord? failure,
    String notes = '',
  }) => DeliveryOrder(
    id: id,
    number: 'ICE-${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}-$id',
    dealerName: dealer,
    dealerPhone: '+919876543210',
    address: address,
    items: items,
    deliveryDate: day,
    slot: slot,
    payment: payment,
    deliveryOtp: otp,
    events: events ?? [StatusEvent(DeliveryStatus.assigned, DateTime.now())],
    delivery: delivery,
    failure: failure,
    notes: notes,
  );

  Future<void> _addTodaysSamples() async {
    final now = DateTime.now();
    final today = dateOnly(now);
    final stamp = today.toIso8601String();
    if (_store.readMap(_seedDateKey)?['date'] == stamp) return;
    final isFirstRun = _store.readMap(_seedDateKey) == null;
    await _store.writeMap(_seedDateKey, {'date': stamp});
    final key = '${today.month}${today.day}';
    final yesterday = today.subtract(const Duration(days: 1));
    final fresh = [
      _sample(
        'A$key',
        today,
        'Sample Cold Traders',
        'Unit 12, Sample Estate, Andheri East, Mumbai 400069',
        const [_cube, _tube],
        PaymentType.cashOnDelivery,
        '9 AM - 12 PM',
        '4821',
        notes: 'Use the back gate.',
      ),
      _sample(
        'B$key',
        today,
        'Sample Fish Market',
        'Stall 8, Sample Market, Versova, Mumbai 400061',
        const [_block],
        PaymentType.credit,
        '12 PM - 3 PM',
        '7350',
      ),
      _sample(
        'C$key',
        today,
        'Sample Hotel',
        '14 Sample Road, Juhu, Mumbai 400049',
        const [_cube],
        PaymentType.prepaid,
        '3 PM - 6 PM',
        '2964',
      ),
      if (isFirstRun) ...[
        _sample(
          'D$key',
          yesterday,
          'Sample Cafe',
          '3 Sample Lane, Bandra West, Mumbai 400050',
          const [_tube],
          PaymentType.credit,
          '9 AM - 12 PM',
          '1188',
          events: [
            StatusEvent(DeliveryStatus.assigned, yesterday),
            StatusEvent(DeliveryStatus.delivered, yesterday.add(const Duration(hours: 11))),
          ],
          delivery: DeliveryRecord(
            delivered: const {'tube-20': 8},
            receivedBy: 'Sample Manager',
            photos: const [],
            at: yesterday.add(const Duration(hours: 11)),
          ),
        ),
        _sample(
          'E$key',
          yesterday,
          'Sample Bar',
          '9 Sample Street, Khar West, Mumbai 400052',
          const [_cube],
          PaymentType.cashOnDelivery,
          '6 PM - 9 PM',
          '6402',
          events: [
            StatusEvent(DeliveryStatus.assigned, yesterday),
            StatusEvent(DeliveryStatus.failed, yesterday.add(const Duration(hours: 19))),
          ],
          failure: FailureRecord(
            reason: 'Shop closed',
            at: yesterday.add(const Duration(hours: 19)),
            note: 'Sample failed delivery.',
          ),
        ),
      ],
    ];
    await _write([..._read(), ...fresh]);
    await _notifications.add(
      NotificationType.order,
      'New orders assigned',
      'You have ${fresh.where((o) => o.isPending).length} new deliveries today.',
      route: '/orders',
    );
  }

  @override
  Future<List<DeliveryOrder>> orders() async {
    await fakeLatency();
    await _addTodaysSamples();
    return _read()..sort((a, b) => b.deliveryDate.compareTo(a.deliveryDate));
  }

  /// Changes one order, first checking it is in a state that allows this.
  Future<DeliveryOrder> _update(
    String orderId,
    Set<DeliveryStatus> allowedFrom,
    DeliveryOrder Function(DeliveryOrder) change,
  ) async {
    await fakeLatency();
    final items = _read();
    final index = items.indexWhere((o) => o.id == orderId);
    if (index < 0) throw const AppException('Order not found');
    if (!allowedFrom.contains(items[index].status)) {
      throw AppException('This order is already ${items[index].status.label.toLowerCase()}.');
    }
    final updated = change(items[index]);
    items[index] = updated;
    await _write(items);
    return updated;
  }

  List<StatusEvent> _withStatus(DeliveryOrder o, DeliveryStatus status, DateTime at) => [
    ...o.events,
    StatusEvent(status, at),
  ];

  @override
  Future<void> accept(String orderId) => _update(orderId, const {
    DeliveryStatus.assigned,
  }, (o) => o.copyWith(events: _withStatus(o, DeliveryStatus.accepted, DateTime.now())));

  @override
  Future<void> reject(String orderId, String reason) async {
    await fakeLatency();
    final items = _read();
    final order = items.where((o) => o.id == orderId).firstOrNull;
    if (order == null || order.status != DeliveryStatus.assigned) {
      throw const AppException('This order can no longer be rejected.');
    }
    await _write(items..remove(order));
    await _notifications.add(
      NotificationType.order,
      'Order returned',
      '${order.number} was returned to the admin: $reason.',
    );
  }

  @override
  Future<void> confirmPickup(String orderId, PickupRecord pickup) => _update(orderId, const {
    DeliveryStatus.accepted,
  }, (o) => o.copyWith(pickup: pickup, events: _withStatus(o, DeliveryStatus.pickedUp, pickup.at)));

  @override
  Future<void> startDelivery(String orderId) => _update(orderId, const {
    DeliveryStatus.pickedUp,
  }, (o) => o.copyWith(events: _withStatus(o, DeliveryStatus.outForDelivery, DateTime.now())));

  @override
  Future<void> completeDelivery(String orderId, String otp, DeliveryRecord delivery) async {
    final existing = _read().where((o) => o.id == orderId).firstOrNull;
    if (existing != null && existing.otpRequired && existing.deliveryOtp != otp) {
      await fakeLatency();
      throw const AppException('Incorrect OTP. Ask the dealer to check the code in their app.');
    }
    final order = await _update(orderId, const {
      DeliveryStatus.outForDelivery,
    }, (o) => o.copyWith(delivery: delivery, events: _withStatus(o, DeliveryStatus.delivered, delivery.at)));
    if (delivery.collected > 0 && delivery.collectionMode != null) {
      await _collections.recordCollection(
        orderNumber: order.number,
        dealerName: order.dealerName,
        amount: delivery.collected,
        mode: delivery.collectionMode!,
        reference: delivery.collectionReference,
        at: delivery.at,
      );
    }
    await _notifications.add(
      NotificationType.order,
      'Delivery completed',
      '${order.number} delivered to ${order.dealerName}.',
      route: '/orders/${order.id}',
    );
  }

  @override
  Future<void> updateDelivery(String orderId, DeliveryRecord delivery) =>
      _update(orderId, const {DeliveryStatus.delivered}, (o) => o.copyWith(delivery: delivery));

  @override
  Future<void> markFailed(String orderId, FailureRecord failure) async {
    final order = await _update(orderId, const {
      DeliveryStatus.accepted,
      DeliveryStatus.pickedUp,
      DeliveryStatus.outForDelivery,
    }, (o) => o.copyWith(failure: failure, events: _withStatus(o, DeliveryStatus.failed, failure.at)));
    await _notifications.add(
      NotificationType.order,
      'Delivery failed',
      '${order.number}: ${failure.reason}. Return the stock to the factory.',
      route: '/orders/${order.id}',
    );
  }
}
