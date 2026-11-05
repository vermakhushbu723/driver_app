import '../../../core/utils/formatters.dart';
import '../../orders/domain/delivery_order.dart';

class CollectionEntry {
  const CollectionEntry({
    required this.orderNumber,
    required this.dealerName,
    required this.amount,
    required this.mode,
    required this.at,
    this.reference = '',
  });

  final String orderNumber;
  final String dealerName;
  final double amount;
  final CollectionMode mode;
  final DateTime at;
  final String reference;

  Map<String, dynamic> toJson() => {
    'orderNumber': orderNumber,
    'dealerName': dealerName,
    'amount': amount,
    'mode': mode.name,
    'at': at.toIso8601String(),
    'reference': reference,
  };

  factory CollectionEntry.fromJson(Map<String, dynamic> j) => CollectionEntry(
    orderNumber: j['orderNumber'] as String,
    dealerName: j['dealerName'] as String,
    amount: (j['amount'] as num).toDouble(),
    mode: CollectionMode.values.byName(j['mode'] as String),
    at: DateTime.parse(j['at'] as String),
    reference: j['reference'] as String,
  );
}

class CashDeposit {
  const CashDeposit({required this.amount, required this.at, required this.reference});

  final double amount;
  final DateTime at;
  final String reference;

  Map<String, dynamic> toJson() => {'amount': amount, 'at': at.toIso8601String(), 'reference': reference};

  factory CashDeposit.fromJson(Map<String, dynamic> j) => CashDeposit(
    amount: (j['amount'] as num).toDouble(),
    at: DateTime.parse(j['at'] as String),
    reference: j['reference'] as String,
  );
}

class CollectionSummary {
  const CollectionSummary({required this.entries, required this.deposits});

  /// Newest first.
  final List<CollectionEntry> entries;
  final List<CashDeposit> deposits;

  double totalOn(DateTime day) =>
      roundMoney(entries.where((e) => isSameDay(e.at, day)).fold(0.0, (sum, e) => sum + e.amount));

  /// Cash the rider still has to hand over. UPI goes straight to the company.
  double get cashInHand {
    final cash = entries.where((e) => e.mode == CollectionMode.cash).fold(0.0, (sum, e) => sum + e.amount);
    final deposited = deposits.fold(0.0, (sum, d) => sum + d.amount);
    return roundMoney(cash - deposited);
  }
}

abstract interface class CollectionRepository {
  Future<CollectionSummary> summary();

  Future<void> recordCollection({
    required String orderNumber,
    required String dealerName,
    required double amount,
    required CollectionMode mode,
    required String reference,
    required DateTime at,
  });

  /// Throws if [amount] is more than the cash in hand.
  Future<void> depositCash(double amount, String reference);
}
