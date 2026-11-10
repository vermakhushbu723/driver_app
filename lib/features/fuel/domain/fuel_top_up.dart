import 'dart:ui';

import '../../../core/theme/app_colors.dart';

enum FuelStatus {
  pending('Waiting for approval', AppColors.amber600),
  approved('Approved', AppColors.green600),
  rejected('Rejected', AppColors.red600);

  const FuelStatus(this.label, this.color);

  final String label;
  final Color color;
}

/// Fuel the company paid for. The rider records a video at the pump as proof; staff approve it.
class FuelTopUp {
  const FuelTopUp({
    required this.id,
    required this.amount,
    required this.litres,
    required this.video,
    required this.at,
    required this.status,
    this.odometerKm,
    this.pump = '',
    this.note = '',
    this.remark = '',
  });

  final String id;
  final double amount;
  final double litres;
  final int? odometerKm;
  final String pump;
  final String video;
  final String note;
  final DateTime at;
  final FuelStatus status;

  /// Why staff rejected it.
  final String remark;

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'litres': litres,
    'odometerKm': odometerKm,
    'pump': pump,
    'video': video,
    'note': note,
    'at': at.toIso8601String(),
    'status': status.name,
    'remark': remark,
  };

  factory FuelTopUp.fromJson(Map<String, dynamic> j) => FuelTopUp(
    id: j['id'] as String,
    amount: (j['amount'] as num).toDouble(),
    litres: (j['litres'] as num).toDouble(),
    odometerKm: (j['odometerKm'] as num?)?.toInt(),
    pump: j['pump'] as String? ?? '',
    video: j['video'] as String? ?? '',
    note: j['note'] as String? ?? '',
    at: DateTime.parse(j['at'] as String),
    status: FuelStatus.values.asNameMap()[j['status']] ?? FuelStatus.pending,
    remark: j['remark'] as String? ?? '',
  );
}

/// This month's fuel, not counting rejected top-ups.
class FuelMonth {
  const FuelMonth({required this.amount, required this.litres, required this.count});

  final double amount;
  final double litres;
  final int count;

  factory FuelMonth.fromJson(Map<String, dynamic> j) =>
      FuelMonth(amount: (j['amount'] as num).toDouble(), litres: (j['litres'] as num).toDouble(), count: (j['count'] as num).toInt());
}

class FuelAccount {
  const FuelAccount(this.topUps, this.month);

  final List<FuelTopUp> topUps;
  final FuelMonth month;
}

class NewFuelTopUp {
  const NewFuelTopUp({required this.amount, required this.litres, required this.videoPath, this.odometerKm, this.pump = '', this.note = ''});

  final double amount;
  final double litres;
  final int? odometerKm;
  final String pump;
  final String note;

  /// The recorded clip on the phone, uploaded when the top-up is sent.
  final String videoPath;
}

abstract interface class FuelRepository {
  Future<FuelAccount> account();

  Future<FuelTopUp> send(NewFuelTopUp topUp);
}
