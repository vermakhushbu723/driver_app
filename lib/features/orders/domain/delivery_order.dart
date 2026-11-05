import '../../../core/location/location_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/photo_field.dart';

enum DeliveryStatus { assigned, accepted, pickedUp, outForDelivery, delivered, failed }

enum PaymentType { credit, prepaid, cashOnDelivery }

enum CollectionMode { cash, upi }

extension DeliveryStatusLabel on DeliveryStatus {
  String get label => switch (this) {
    DeliveryStatus.assigned => 'Assigned',
    DeliveryStatus.accepted => 'Accepted',
    DeliveryStatus.pickedUp => 'Picked up',
    DeliveryStatus.outForDelivery => 'Out for delivery',
    DeliveryStatus.delivered => 'Delivered',
    DeliveryStatus.failed => 'Failed',
  };
}

extension PaymentTypeLabel on PaymentType {
  String get label => switch (this) {
    PaymentType.credit => 'On dealer credit',
    PaymentType.prepaid => 'Paid online',
    PaymentType.cashOnDelivery => 'Collect on delivery',
  };
}

extension CollectionModeLabel on CollectionMode {
  String get label => switch (this) {
    CollectionMode.cash => 'Cash',
    CollectionMode.upi => 'UPI',
  };
}

class OrderItem {
  const OrderItem({
    required this.id,
    required this.name,
    required this.packSize,
    required this.unit,
    required this.quantity,
    required this.rate,
  });

  final String id;
  final String name;
  final String packSize;
  final String unit;
  final int quantity;

  /// Price per unit including GST, used for what to collect from the dealer.
  final double rate;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'packSize': packSize,
    'unit': unit,
    'quantity': quantity,
    'rate': rate,
  };

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
    id: j['id'] as String,
    name: j['name'] as String,
    packSize: j['packSize'] as String,
    unit: j['unit'] as String,
    quantity: j['quantity'] as int,
    rate: (j['rate'] as num).toDouble(),
  );
}

class StatusEvent {
  const StatusEvent(this.status, this.at);

  final DeliveryStatus status;
  final DateTime at;

  Map<String, dynamic> toJson() => {'status': status.name, 'at': at.toIso8601String()};

  factory StatusEvent.fromJson(Map<String, dynamic> j) =>
      StatusEvent(DeliveryStatus.values.byName(j['status'] as String), DateTime.parse(j['at'] as String));
}

class PickupRecord {
  const PickupRecord({required this.loaded, required this.photos, required this.at, this.remark = '', this.location});

  /// Item id to the quantity loaded onto the vehicle.
  final Map<String, int> loaded;
  final List<CapturedPhoto> photos;
  final DateTime at;
  final String remark;
  final GeoPoint? location;

  Map<String, dynamic> toJson() => {
    'loaded': loaded,
    'photos': photos.map((p) => p.toJson()).toList(),
    'at': at.toIso8601String(),
    'remark': remark,
    'location': location?.toJson(),
  };

  factory PickupRecord.fromJson(Map<String, dynamic> j) => PickupRecord(
    loaded: (j['loaded'] as Map).cast<String, int>(),
    photos: (j['photos'] as List).map((p) => CapturedPhoto.fromJson(p as Map<String, dynamic>)).toList(),
    at: DateTime.parse(j['at'] as String),
    remark: j['remark'] as String,
    location: j['location'] == null ? null : GeoPoint.fromJson(j['location'] as Map<String, dynamic>),
  );
}

class DeliveryRecord {
  const DeliveryRecord({
    required this.delivered,
    required this.receivedBy,
    required this.photos,
    required this.at,
    this.remark = '',
    this.location,
    this.collected = 0,
    this.collectionMode,
    this.collectionReference = '',
  });

  /// Item id to the quantity the dealer accepted.
  final Map<String, int> delivered;
  final String receivedBy;
  final List<CapturedPhoto> photos;
  final DateTime at;
  final String remark;
  final GeoPoint? location;
  final double collected;
  final CollectionMode? collectionMode;
  final String collectionReference;

  DeliveryRecord copyWith({String? receivedBy, List<CapturedPhoto>? photos}) => DeliveryRecord(
    delivered: delivered,
    receivedBy: receivedBy ?? this.receivedBy,
    photos: photos ?? this.photos,
    at: at,
    remark: remark,
    location: location,
    collected: collected,
    collectionMode: collectionMode,
    collectionReference: collectionReference,
  );

  Map<String, dynamic> toJson() => {
    'delivered': delivered,
    'receivedBy': receivedBy,
    'photos': photos.map((p) => p.toJson()).toList(),
    'at': at.toIso8601String(),
    'remark': remark,
    'location': location?.toJson(),
    'collected': collected,
    'collectionMode': collectionMode?.name,
    'collectionReference': collectionReference,
  };

  factory DeliveryRecord.fromJson(Map<String, dynamic> j) => DeliveryRecord(
    delivered: (j['delivered'] as Map).cast<String, int>(),
    receivedBy: j['receivedBy'] as String,
    photos: (j['photos'] as List).map((p) => CapturedPhoto.fromJson(p as Map<String, dynamic>)).toList(),
    at: DateTime.parse(j['at'] as String),
    remark: j['remark'] as String,
    location: j['location'] == null ? null : GeoPoint.fromJson(j['location'] as Map<String, dynamic>),
    collected: (j['collected'] as num).toDouble(),
    collectionMode: j['collectionMode'] == null ? null : CollectionMode.values.byName(j['collectionMode'] as String),
    collectionReference: j['collectionReference'] as String,
  );
}

class FailureRecord {
  const FailureRecord({required this.reason, required this.at, this.note = '', this.photos = const [], this.location});

  final String reason;
  final DateTime at;
  final String note;
  final List<CapturedPhoto> photos;
  final GeoPoint? location;

  Map<String, dynamic> toJson() => {
    'reason': reason,
    'at': at.toIso8601String(),
    'note': note,
    'photos': photos.map((p) => p.toJson()).toList(),
    'location': location?.toJson(),
  };

  factory FailureRecord.fromJson(Map<String, dynamic> j) => FailureRecord(
    reason: j['reason'] as String,
    at: DateTime.parse(j['at'] as String),
    note: j['note'] as String,
    photos: (j['photos'] as List).map((p) => CapturedPhoto.fromJson(p as Map<String, dynamic>)).toList(),
    location: j['location'] == null ? null : GeoPoint.fromJson(j['location'] as Map<String, dynamic>),
  );
}

class DeliveryOrder {
  const DeliveryOrder({
    required this.id,
    required this.number,
    required this.dealerName,
    required this.dealerPhone,
    required this.address,
    required this.items,
    required this.deliveryDate,
    required this.slot,
    required this.payment,
    required this.deliveryOtp,
    required this.events,
    this.notes = '',
    this.pickup,
    this.delivery,
    this.failure,
  });

  final String id;
  final String number;
  final String dealerName;
  final String dealerPhone;
  final String address;
  final List<OrderItem> items;
  final DateTime deliveryDate;
  final String slot;
  final PaymentType payment;

  /// The dealer gives this to the rider to confirm the delivery.
  final String deliveryOtp;
  final List<StatusEvent> events;
  final String notes;
  final PickupRecord? pickup;
  final DeliveryRecord? delivery;
  final FailureRecord? failure;

  DeliveryStatus get status => events.last.status;
  bool get isDone => status == DeliveryStatus.delivered || status == DeliveryStatus.failed;
  bool get isPending => !isDone;
  bool get canFail =>
      status == DeliveryStatus.accepted || status == DeliveryStatus.pickedUp || status == DeliveryStatus.outForDelivery;
  bool get collectsPayment => payment == PaymentType.cashOnDelivery;
  int get totalUnits => items.fold(0, (sum, i) => sum + i.quantity);

  int loadedOf(OrderItem item) => pickup?.loaded[item.id] ?? item.quantity;

  /// What the dealer owes on delivery for these quantities. The dealer only
  /// pays for what they accept, so a short delivery means a smaller bill.
  double amountDue(Map<String, int> delivered) {
    if (!collectsPayment) return 0;
    final total = items.fold<double>(0, (sum, i) => sum + i.rate * (delivered[i.id] ?? 0));
    return roundMoney(total);
  }

  /// The full bill, before any short load or short delivery.
  double get orderValue => roundMoney(items.fold<double>(0, (sum, i) => sum + i.rate * i.quantity));

  DeliveryOrder copyWith({
    List<StatusEvent>? events,
    PickupRecord? pickup,
    DeliveryRecord? delivery,
    FailureRecord? failure,
  }) => DeliveryOrder(
    id: id,
    number: number,
    dealerName: dealerName,
    dealerPhone: dealerPhone,
    address: address,
    items: items,
    deliveryDate: deliveryDate,
    slot: slot,
    payment: payment,
    deliveryOtp: deliveryOtp,
    events: events ?? this.events,
    notes: notes,
    pickup: pickup ?? this.pickup,
    delivery: delivery ?? this.delivery,
    failure: failure ?? this.failure,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'dealerName': dealerName,
    'dealerPhone': dealerPhone,
    'address': address,
    'items': items.map((i) => i.toJson()).toList(),
    'deliveryDate': deliveryDate.toIso8601String(),
    'slot': slot,
    'payment': payment.name,
    'deliveryOtp': deliveryOtp,
    'events': events.map((e) => e.toJson()).toList(),
    'notes': notes,
    'pickup': pickup?.toJson(),
    'delivery': delivery?.toJson(),
    'failure': failure?.toJson(),
  };

  factory DeliveryOrder.fromJson(Map<String, dynamic> j) => DeliveryOrder(
    id: j['id'] as String,
    number: j['number'] as String,
    dealerName: j['dealerName'] as String,
    dealerPhone: j['dealerPhone'] as String,
    address: j['address'] as String,
    items: (j['items'] as List).map((i) => OrderItem.fromJson(i as Map<String, dynamic>)).toList(),
    deliveryDate: DateTime.parse(j['deliveryDate'] as String),
    slot: j['slot'] as String,
    payment: PaymentType.values.byName(j['payment'] as String),
    deliveryOtp: j['deliveryOtp'] as String,
    events: (j['events'] as List).map((e) => StatusEvent.fromJson(e as Map<String, dynamic>)).toList(),
    notes: j['notes'] as String,
    pickup: j['pickup'] == null ? null : PickupRecord.fromJson(j['pickup'] as Map<String, dynamic>),
    delivery: j['delivery'] == null ? null : DeliveryRecord.fromJson(j['delivery'] as Map<String, dynamic>),
    failure: j['failure'] == null ? null : FailureRecord.fromJson(j['failure'] as Map<String, dynamic>),
  );
}

abstract interface class OrderRepository {
  /// Newest delivery date first.
  Future<List<DeliveryOrder>> orders();

  Future<void> accept(String orderId);

  /// Hands the order back to the admin, so it leaves this rider's list.
  Future<void> reject(String orderId, String reason);

  Future<void> confirmPickup(String orderId, PickupRecord pickup);

  Future<void> startDelivery(String orderId);

  /// Throws if [otp] doesn't match, and posts any money collected.
  Future<void> completeDelivery(String orderId, String otp, DeliveryRecord delivery);

  /// Adds proof to a finished delivery, such as a late photo or the receiver's name.
  Future<void> updateDelivery(String orderId, DeliveryRecord delivery);

  Future<void> markFailed(String orderId, FailureRecord failure);
}
