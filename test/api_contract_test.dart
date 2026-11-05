@Tags(['contract'])
library;

import 'dart:io';

import 'package:driver_app/core/location/location_service.dart';
import 'package:driver_app/core/network/api_client.dart';
import 'package:driver_app/core/storage/local_store.dart';
import 'package:driver_app/core/widgets/photo_field.dart';
import 'package:driver_app/features/attendance/data/api_attendance_repository.dart';
import 'package:driver_app/features/auth/data/api_auth_repository.dart';
import 'package:driver_app/features/collection/data/api_collection_repository.dart';
import 'package:driver_app/features/notifications/data/api_notification_repository.dart';
import 'package:driver_app/features/orders/data/api_order_repository.dart';
import 'package:driver_app/features/orders/domain/delivery_order.dart';
import 'package:driver_app/features/pickup/data/api_factory_repository.dart';
import 'package:driver_app/features/returns/data/api_return_repository.dart';
import 'package:driver_app/features/returns/domain/return_report.dart';
import 'package:driver_app/features/support/data/api_support_repository.dart';
import 'package:driver_app/features/tracking/data/api_tracking_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Runs the app's real data code against a real server. See the dealer app's test for how to run it.
void main() {
  late ApiClient api;
  late ApiClient adminApi;
  late ApiClient dealerApi;

  Future<CapturedPhoto> photo() async {
    final file = File('${Directory.systemTemp.path}/iceclub_contract_rider.png');
    await file.writeAsBytes(const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0]);
    return CapturedPhoto(file.path, DateTime.now());
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    api = ApiClient(LocalStore(prefs, scope: 'rider'));
    adminApi = ApiClient(LocalStore(prefs, scope: 'admin'));
    dealerApi = ApiClient(LocalStore(prefs, scope: 'dealer'));
    final admin = await adminApi.post('/auth/admin/login', {'email': 'admin@iceclub.online', 'password': 'Admin@1234'}) as Map<String, dynamic>;
    await adminApi.saveToken(admin['token'] as String);
    final dealer = await dealerApi.post('/auth/dealer/login', {'phone': '9876543210', 'password': 'Demo@1234'}) as Map<String, dynamic>;
    await dealerApi.saveToken(dealer['token'] as String);
  });

  /// A dealer's order, moved by staff, assigned to this rider.
  Future<Map<String, dynamic>> newOrder(String paymentMethod) async {
    final order = await dealerApi.post('/dealer/orders', {
      'addressId': 'D1-A1',
      'items': [{'productId': 'block-50', 'qty': 5}],
      'paymentMethod': paymentMethod,
      'deliveryDate': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      'slot': '9 AM - 12 PM',
    }) as Map<String, dynamic>;
    await adminApi.post('/admin/actions/assignRider', {'args': [order['id'], 'R1']});
    return order;
  }

  Future<void> advance(String id, int times) async {
    for (var i = 0; i < times; i++) {
      await adminApi.post('/admin/actions/advanceOrder', {'args': [id]});
    }
  }

  test('a rider’s whole day', () async {
    final auth = ApiAuthRepository(api);
    expect(await auth.currentRider(), isNull);
    await expectLater(auth.sendOtp('9812999999'), throwsA(isA<ApiException>()));
    await auth.sendOtp('9000000001');
    final rider = await auth.verifyOtp('9000000001', '123456');
    expect(rider.name, isNotEmpty);
    expect((await auth.setOnDuty(true)).onDuty, isTrue);
    await auth.changePassword(current: 'Rider@1234', next: 'Rider@1234');
    expect((await auth.signInWithPassword('9000000001', 'Rider@1234')).id, rider.id);

    final factory = await ApiFactoryRepository(api).assignedFactory();
    expect(factory.name, isNotEmpty);

    final attendance = ApiAttendanceRepository(api);
    if (await attendance.today() == null) {
      await attendance.checkIn(const GeoPoint(19.1, 72.8));
      await expectLater(attendance.checkIn(null), throwsA(isA<ApiException>()));
      expect((await attendance.today())!.checkOut, isNull);
      await attendance.checkOut(const GeoPoint(19.1, 72.8));
    }
    expect(await attendance.days(), isNotEmpty);

    final earnings = ApiEarningsRepository(api);
    expect((await earnings.salaries()).length, 4);
    expect((await earnings.incentives()).length, 2);

    final tracking = ApiTrackingRepository(api);
    await tracking.startDuty();
    await tracking.addPoint(const GeoPoint(19.12, 72.85));
    expect((await tracking.pointsOn(DateTime.now())).single.location.latitude, 19.12);
    expect(await tracking.sessions(), isNotEmpty);
    await tracking.stopDuty();

    final orders = ApiOrderRepository(api);
    expect(await orders.orders(), isNotEmpty);

    // Reject one.
    final rejected = await newOrder('cashOnDelivery');
    await orders.reject(rejected['id'] as String, 'Vehicle broke down');
    expect((await orders.orders()).any((o) => o.id == rejected['id']), isFalse);

    // Deliver one, collecting cash, with one bag short.
    final cod = await newOrder('cashOnDelivery');
    final codId = cod['id'] as String;
    final assigned = (await orders.orders()).firstWhere((o) => o.id == codId);
    expect(assigned.status, DeliveryStatus.assigned);
    expect(assigned.deliveryOtp, isEmpty, reason: 'the rider must never see the OTP');
    await orders.accept(codId);
    await advance(codId, 3);
    await orders.confirmPickup(codId, PickupRecord(loaded: const {'block-50': 5}, photos: [await photo()], at: DateTime.now(), remark: 'Loaded', location: const GeoPoint(19.1, 72.8)));
    expect((await orders.orders()).firstWhere((o) => o.id == codId).pickup!.photos.single.path, startsWith('http'));
    await orders.startDelivery(codId);
    final moving = (await orders.orders()).firstWhere((o) => o.id == codId);
    expect(moving.status, DeliveryStatus.outForDelivery);

    final delivered = {'block-50': 4};
    final collected = moving.amountDue(delivered);
    DeliveryRecord record(double amount) => DeliveryRecord(delivered: delivered, receivedBy: 'Manager', photos: const [], at: DateTime.now(), remark: 'One short', location: const GeoPoint(19.13, 72.86), collected: amount, collectionMode: CollectionMode.cash);
    await expectLater(orders.completeDelivery(codId, '0000', record(collected)), throwsA(isA<ApiException>()));
    await orders.completeDelivery(codId, cod['deliveryOtp'] as String, record(collected));
    final done = (await orders.orders()).firstWhere((o) => o.id == codId);
    expect(done.status, DeliveryStatus.delivered);
    expect(done.delivery!.collected, collected);
    await orders.updateDelivery(codId, done.delivery!.copyWith(receivedBy: 'Owner', photos: [await photo()]));
    expect((await orders.orders()).firstWhere((o) => o.id == codId).delivery!.receivedBy, 'Owner');

    final collections = ApiCollectionRepository(api);
    final before = await collections.summary();
    expect(before.entries.first.amount, collected);
    expect(before.cashInHand, greaterThan(0));
    await expectLater(collections.depositCash(before.cashInHand + 100, 'TOO-MUCH'), throwsA(isA<ApiException>()));
    await collections.depositCash(100, 'CONTRACT-SLIP');
    expect((await collections.summary()).cashInHand, before.cashInHand - 100);

    // A credit order that fails.
    final failed = await newOrder('cashOnDelivery');
    final failedId = failed['id'] as String;
    await orders.accept(failedId);
    await advance(failedId, 3);
    await orders.confirmPickup(failedId, PickupRecord(loaded: const {'block-50': 5}, photos: const [], at: DateTime.now()));
    await orders.startDelivery(failedId);
    await orders.markFailed(failedId, FailureRecord(reason: 'Shop closed', at: DateTime.now(), note: 'Nobody there', photos: [await photo()], location: const GeoPoint(19.1, 72.8)));
    final lost = (await orders.orders()).firstWhere((o) => o.id == failedId);
    expect(lost.status, DeliveryStatus.failed);
    expect(lost.failure!.reason, 'Shop closed');
    await adminApi.post('/admin/actions/retryDelivery', {'args': [failedId]});
    expect((await orders.orders()).firstWhere((o) => o.id == failedId).failure!.reason, 'Shop closed', reason: 'stays in history');

    final returns = ApiReturnRepository(api);
    await returns.submit(ReturnReport(id: 'x', type: ReturnType.meltedIce, orderId: codId, orderNumber: done.number, dealerName: done.dealerName, quantity: 1, note: 'Melted', photos: [await photo()], at: DateTime.now(), location: const GeoPoint(19, 72)));
    final reports = await returns.reports();
    expect(reports.first.type, ReturnType.meltedIce);

    final notifications = ApiNotificationRepository(api);
    expect(await notifications.notifications(), isNotEmpty);
    await notifications.markAllRead();
    await notifications.clearAll();

    final support = ApiSupportRepository(api);
    final ticket = await support.create(subject: 'Contract', category: 'Vehicle', message: 'Hello');
    expect(ticket.messages.first.fromRider, isTrue);
    await support.reply(ticket.id, 'More');
    await support.resolve(ticket.id);
    expect(await support.tickets(), isNotEmpty);

    expect((await auth.setOnDuty(false)).onDuty, isFalse);
    await auth.logout();
    expect(await auth.currentRider(), isNull);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
