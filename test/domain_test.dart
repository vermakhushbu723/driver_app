import 'package:driver_app/core/error/app_exception.dart';
import 'package:driver_app/core/location/location_service.dart';
import 'package:driver_app/core/storage/local_store.dart';
import 'package:driver_app/features/attendance/data/fake_attendance_repository.dart';
import 'package:driver_app/features/attendance/domain/attendance.dart';
import 'package:driver_app/features/collection/data/fake_collection_repository.dart';
import 'package:driver_app/features/collection/domain/collection.dart';
import 'package:driver_app/features/notifications/data/fake_notification_repository.dart';
import 'package:driver_app/features/orders/data/fake_order_repository.dart';
import 'package:driver_app/features/orders/domain/delivery_order.dart';
import 'package:driver_app/features/tracking/domain/tracking.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

DeliveryOrder _order({PaymentType payment = PaymentType.cashOnDelivery, PickupRecord? pickup}) => DeliveryOrder(
  id: '1',
  number: 'ICE-1',
  dealerName: 'Dealer',
  dealerPhone: '',
  address: '',
  items: const [
    OrderItem(id: 'a', name: 'Cube', packSize: '', unit: 'bag', quantity: 10, rate: 100),
    OrderItem(id: 'b', name: 'Block', packSize: '', unit: 'block', quantity: 2, rate: 350.5),
  ],
  deliveryDate: DateTime(2026, 11, 2),
  slot: '',
  payment: payment,
  deliveryOtp: '1234',
  events: [StatusEvent(DeliveryStatus.assigned, DateTime(2026, 11, 2))],
  pickup: pickup,
);

void main() {
  group('amount due', () {
    test('charges only what the dealer accepts', () {
      expect(_order().amountDue({'a': 10, 'b': 2}), 1701);
      expect(_order().amountDue({'a': 7, 'b': 0}), 700);
      expect(_order().amountDue({}), 0);
    });

    test('is nothing for credit and prepaid orders', () {
      expect(_order(payment: PaymentType.credit).amountDue({'a': 10}), 0);
      expect(_order(payment: PaymentType.prepaid).amountDue({'a': 10}), 0);
    });
  });

  test('delivery can not exceed what was loaded', () {
    final pickup = PickupRecord(loaded: const {'a': 8, 'b': 2}, photos: const [], at: DateTime(2026, 11, 2));
    final order = _order(pickup: pickup);
    expect(order.loadedOf(order.items.first), 8);
    expect(_order().loadedOf(order.items.first), 10);
  });

  group('cash in hand', () {
    final at = DateTime(2026, 11, 2, 12);
    CollectionEntry entry(double amount, CollectionMode mode, [DateTime? on]) =>
        CollectionEntry(orderNumber: '', dealerName: '', amount: amount, mode: mode, at: on ?? at);

    test('counts cash but not UPI, and subtracts deposits', () {
      final summary = CollectionSummary(
        entries: [entry(1000, CollectionMode.cash), entry(500, CollectionMode.upi)],
        deposits: [CashDeposit(amount: 300, at: at, reference: 'x')],
      );
      expect(summary.cashInHand, 700);
    });

    test('today\'s collection includes UPI and leaves out other days', () {
      final summary = CollectionSummary(
        entries: [
          entry(1000, CollectionMode.cash),
          entry(500, CollectionMode.upi),
          entry(900, CollectionMode.cash, DateTime(2026, 11, 1)),
        ],
        deposits: const [],
      );
      expect(summary.totalOn(at), 1500);
    });
  });

  group('route distance', () {
    RoutePoint point(double lat, double lng) => RoutePoint(GeoPoint(lat, lng), DateTime(2026, 11, 2));

    test('adds up the legs of a route', () {
      // One degree of latitude is about 111 km.
      expect(routeDistanceKm([point(19, 72), point(20, 72)]), closeTo(111.2, 0.5));
    });

    test('ignores GPS jitter while standing still', () {
      expect(routeDistanceKm([point(19, 72), point(19.00001, 72), point(19, 72.00001)]), 0);
    });

    test('is zero with too few points', () {
      expect(routeDistanceKm(const []), 0);
      expect(routeDistanceKm([point(19, 72)]), 0);
    });
  });

  group('salary', () {
    SalaryMonth month(int present) => SalaryMonth(
      month: DateTime(2026, 11),
      baseSalary: 26000,
      presentDays: present,
      workingDays: 26,
      incentives: 500,
      deductions: 100,
    );

    test('pays for days worked, plus incentives, minus deductions', () {
      expect(month(13).earned, 13000);
      expect(month(13).net, 13400);
    });

    test('never pays more than the monthly salary for extra days', () {
      expect(month(30).earned, 26000);
    });
  });

  group('attendance', () {
    late FakeAttendanceRepository attendance;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      attendance = FakeAttendanceRepository(LocalStore(await SharedPreferences.getInstance()).scoped('R-test'));
    });

    test('checks in and out once a day, in that order', () async {
      await expectLater(attendance.checkOut(null), throwsA(isA<AppException>()));
      await attendance.checkIn(const GeoPoint(19, 72));
      await expectLater(attendance.checkIn(null), throwsA(isA<AppException>()));
      await attendance.checkOut(null);
      await expectLater(attendance.checkOut(null), throwsA(isA<AppException>()));
      expect((await attendance.days()).single.checkOut, isNotNull);
    });
  });

  group('order repository', () {
    late FakeOrderRepository orders;
    late FakeCollectionRepository collections;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final store = LocalStore(await SharedPreferences.getInstance()).scoped('R-test');
      collections = FakeCollectionRepository(store);
      orders = FakeOrderRepository(store, collections, FakeNotificationRepository(store));
    });

    Future<DeliveryOrder> codOrder() async =>
        (await orders.orders()).firstWhere((o) => o.payment == PaymentType.cashOnDelivery && o.isPending);

    DeliveryRecord delivery(double collected) => DeliveryRecord(
      delivered: const {'cube-20': 12, 'tube-20': 8},
      receivedBy: 'Owner',
      photos: const [],
      at: DateTime.now(),
      collected: collected,
      collectionMode: CollectionMode.cash,
    );

    test('adds samples once per day, not on every read', () async {
      final first = (await orders.orders()).length;
      expect((await orders.orders()).length, first);
    });

    test('steps must happen in order', () async {
      final order = await codOrder();
      await expectLater(orders.startDelivery(order.id), throwsA(isA<AppException>()));
      await orders.accept(order.id);
      await expectLater(orders.accept(order.id), throwsA(isA<AppException>()));
    });

    test('a wrong OTP is refused and nothing is collected', () async {
      final order = await codOrder();
      await orders.accept(order.id);
      await orders.confirmPickup(
        order.id,
        PickupRecord(loaded: const {'cube-20': 12, 'tube-20': 8}, photos: const [], at: DateTime.now()),
      );
      await orders.startDelivery(order.id);

      await expectLater(orders.completeDelivery(order.id, '0000', delivery(500)), throwsA(isA<AppException>()));
      expect((await collections.summary()).entries, isEmpty);

      await orders.completeDelivery(order.id, order.deliveryOtp, delivery(500));
      final updated = (await orders.orders()).firstWhere((o) => o.id == order.id);
      expect(updated.status, DeliveryStatus.delivered);
      expect((await collections.summary()).cashInHand, 500);
    });

    test('rejecting removes the order, and only while it is assigned', () async {
      final order = await codOrder();
      await orders.reject(order.id, 'Vehicle problem');
      expect((await orders.orders()).any((o) => o.id == order.id), isFalse);
      await expectLater(orders.reject(order.id, 'Again'), throwsA(isA<AppException>()));
    });

    test('depositing more than the cash in hand is refused', () async {
      await expectLater(collections.depositCash(1, 'slip'), throwsA(isA<AppException>()));
    });
  });
}
