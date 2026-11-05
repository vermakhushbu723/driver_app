import '../../../core/location/location_service.dart';
import '../../../core/widgets/photo_field.dart';

enum ReturnType { damagedBags, meltedIce, shortQuantity }

extension ReturnTypeLabel on ReturnType {
  String get label => switch (this) {
    ReturnType.damagedBags => 'Damaged bags',
    ReturnType.meltedIce => 'Melted ice',
    ReturnType.shortQuantity => 'Short quantity',
  };
}

class ReturnReport {
  const ReturnReport({
    required this.id,
    required this.type,
    required this.orderId,
    required this.orderNumber,
    required this.dealerName,
    required this.quantity,
    required this.note,
    required this.photos,
    required this.at,
    this.location,
  });

  final String id;
  final ReturnType type;

  /// Every report belongs to the order the stock came from.
  final String orderId;
  final String orderNumber;
  final String dealerName;
  final int quantity;
  final String note;
  final List<CapturedPhoto> photos;
  final DateTime at;
  final GeoPoint? location;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'orderId': orderId,
    'orderNumber': orderNumber,
    'dealerName': dealerName,
    'quantity': quantity,
    'note': note,
    'photos': photos.map((p) => p.toJson()).toList(),
    'at': at.toIso8601String(),
    'location': location?.toJson(),
  };

  factory ReturnReport.fromJson(Map<String, dynamic> j) => ReturnReport(
    id: j['id'] as String,
    type: ReturnType.values.byName(j['type'] as String),
    orderId: j['orderId'] as String,
    orderNumber: j['orderNumber'] as String,
    dealerName: j['dealerName'] as String,
    quantity: j['quantity'] as int,
    note: j['note'] as String,
    photos: (j['photos'] as List).map((p) => CapturedPhoto.fromJson(p as Map<String, dynamic>)).toList(),
    at: DateTime.parse(j['at'] as String),
    location: j['location'] == null ? null : GeoPoint.fromJson(j['location'] as Map<String, dynamic>),
  );
}

abstract interface class ReturnRepository {
  /// Newest first.
  Future<List<ReturnReport>> reports();

  Future<void> submit(ReturnReport report);
}
