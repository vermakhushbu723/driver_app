import 'dart:async';

import 'package:driver_app/app/app.dart';
import 'package:driver_app/app/router.dart';
import 'package:driver_app/app/routes.dart';
import 'package:driver_app/core/location/location_service.dart';
import 'package:driver_app/core/storage/local_store.dart';
import 'package:driver_app/core/widgets/common_widgets.dart';
import 'package:driver_app/core/widgets/photo_field.dart';
import 'package:driver_app/features/auth/presentation/auth_providers.dart';
import 'package:driver_app/features/orders/domain/delivery_order.dart';
import 'package:driver_app/features/orders/presentation/delivery_screens.dart';
import 'package:driver_app/features/returns/domain/return_report.dart';
import 'package:driver_app/features/orders/presentation/order_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  Size size = const Size(1080, 2400),
  double ratio = 2.5,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = ratio;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      localStoreProvider.overrideWithValue(LocalStore(prefs)),
      locateProvider.overrideWithValue(() async => const GeoPoint(19.1, 72.8)),
      photoCaptureProvider.overrideWithValue(() async => CapturedPhoto('proof.jpg', DateTime(2026, 11, 2))),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const RiderApp()));
  await _settle(tester);
  return container;
}

/// Waits out the fake repositories' latency, which only passes while pumping.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Scrolls down to a widget, since long lists only build what is on screen.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(finder.first);
  await tester.pump();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await _reveal(tester, find.text(text));
  await tester.tap(find.text(text).first);
  await _settle(tester);
}

Future<void> _enter(WidgetTester tester, String label, String value) async {
  final field = find.descendant(of: find.widgetWithText(LabeledField, label), matching: find.byType(TextFormField));
  await _reveal(tester, field);
  await tester.enterText(field, value);
  await tester.pump();
}

Future<void> _signIn(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField), '9000000001');
  await _tapText(tester, 'Send OTP');
  await tester.enterText(find.byType(TextField), '123456');
  await _tapText(tester, 'Verify and continue');
}

void main() {
  testWidgets('an unregistered number can not sign in', (tester) async {
    await _pumpApp(tester);
    await tester.enterText(find.byType(TextFormField), '9111111111');
    await _tapText(tester, 'Send OTP');
    expect(find.textContaining('not registered'), findsOneWidget);
    expect(find.text('Rider sign in'), findsOneWidget);
  });

  testWidgets('a rider takes a cash order from assignment to delivery', (tester) async {
    final container = await _pumpApp(tester);
    await _signIn(tester);
    expect(find.text('Hello, Demo Rider'), findsOneWidget);

    final orders = container.read(ordersProvider).value!;
    final order = orders.firstWhere((o) => o.payment == PaymentType.cashOnDelivery && o.isPending);
    final router = container.read(routerProvider);

    router.go(Routes.order(order.id));
    await _settle(tester);
    await _tapText(tester, 'Accept order');
    expect(find.text('Accepted'), findsOneWidget);

    await _tapText(tester, 'Confirm loading at factory');
    expect(find.text('Loading confirmation'), findsOneWidget);

    await _tapText(tester, 'Confirm loading');
    expect(find.textContaining('photo'), findsWidgets, reason: 'A photo is required');
    await _tapText(tester, 'Take photo');
    await _tapText(tester, 'Confirm loading');
    expect(find.textContaining('checked the load'), findsOneWidget);
    await _tapText(tester, 'I have checked the count and the ice is in good condition');
    await _tapText(tester, 'Confirm loading');

    expect(find.text('Order details'), findsOneWidget);
    await _tapText(tester, 'Start delivery');
    await _tapText(tester, 'Complete delivery');
    expect(find.text('Quantity delivered'), findsOneWidget);

    await _tapText(tester, 'Collected in full');
    await _enter(tester, 'Receiver name (optional)', 'Dealer Owner');
    await _tapText(tester, 'Take photo');
    await _enter(tester, 'Delivery OTP from the dealer', '0000');
    await _tapText(tester, 'Confirm delivery');
    expect(find.textContaining('Incorrect OTP'), findsOneWidget);

    // Let the error message clear, as it sits over the button.
    await tester.pump(const Duration(seconds: 5));
    await _settle(tester);
    await _enter(tester, 'Delivery OTP from the dealer', order.deliveryOtp);
    await _tapText(tester, 'Confirm delivery');
    expect(find.text('Delivery completed'), findsWidgets);
    expect(find.text('Delivered'), findsOneWidget);

    router.go(Routes.collection);
    await _settle(tester);
    // 12 cube bags at 348 and 8 tube bags at 330.
    expect(find.text('₹6,816'), findsWidgets);
  });

  testWidgets('the menu lists all twelve sections and opens a sub-menu', (tester) async {
    final container = await _pumpApp(tester);
    unawaited(container.read(authControllerProvider.notifier).verifyOtp('9000000001', '123456'));
    await _settle(tester);
    container.read(routerProvider).go(Routes.menu);
    await _settle(tester);
    expect(find.text('1. Dashboard'), findsOneWidget);
    await _tapText(tester, '9. Attendance and earnings');
    await _tapText(tester, 'Salary');
    expect(find.textContaining('sample figures'), findsOneWidget);
  });

  testWidgets('every screen opens on a small phone', (tester) async {
    final container = await _pumpApp(tester, size: const Size(1080, 1920), ratio: 3); // 360 x 640
    unawaited(container.read(authControllerProvider.notifier).verifyOtp('9000000001', '123456'));
    await _settle(tester);
    final orders = container.read(ordersProvider).value!;
    final id = orders.first.id;
    final failed = orders.firstWhere((o) => o.status == DeliveryStatus.failed).id;
    final delivered = orders.firstWhere((o) => o.status == DeliveryStatus.delivered).id;

    final router = container.read(routerProvider);
    final screens = [
      Routes.home,
      Routes.orders,
      Routes.pickup,
      Routes.collection,
      Routes.menu,
      for (final f in OrderFilter.values) Routes.orderList(f.name),
      Routes.factoryDetails,
      Routes.pickupQuantity,
      Routes.loadingConfirmation,
      Routes.pickupPhotos,
      for (final d in DeliverySection.values) Routes.deliverySection(d.name),
      Routes.duty,
      Routes.liveGps,
      Routes.routeTracking,
      Routes.cashCollection,
      Routes.upiCollection,
      Routes.paymentHistory,
      Routes.cashHandover,
      for (final t in ReturnType.values) ...[Routes.returns(t.name), Routes.newReturn(t.name)],
      Routes.returnPhotos,
      Routes.deliveryHistory,
      Routes.collectionHistory,
      Routes.attendance,
      Routes.salary,
      Routes.incentives,
      Routes.notifications,
      Routes.notificationSettings,
      Routes.support,
      Routes.tickets,
      Routes.newTicket,
      Routes.profile,
      Routes.vehicle,
      Routes.documents,
      Routes.changePassword,
      Routes.order(id),
      Routes.order(failed),
      Routes.order(delivered),
      Routes.loading(id),
      Routes.completeDelivery(id),
      Routes.failDelivery(id),
    ];
    final failures = <String>[];
    for (final screen in screens) {
      router.go(screen);
      await _settle(tester);
      final error = tester.takeException();
      if (error != null) failures.add('$screen: $error');
      if (find.byType(ErrorWidget).evaluate().isNotEmpty) failures.add('$screen: showed an error');
    }
    expect(failures, isEmpty);
  });

  testWidgets('every field on every form has a placeholder', (tester) async {
    tester.view.physicalSize = const Size(1080, 7500);
    tester.view.devicePixelRatio = 3; // tall, so long forms build all their fields
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [localStoreProvider.overrideWithValue(LocalStore(prefs))]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const RiderApp()));
    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    await settle();
    unawaited(container.read(authControllerProvider.notifier).verifyOtp('9000000001', '123456'));
    await settle();

    final router = container.read(routerProvider);
    final id = container.read(ordersProvider).value!.first.id;
    final forms = [
      Routes.cashHandover,
      Routes.newTicket,
      Routes.newReturn(ReturnType.damagedBags.name),
      Routes.changePassword,
      Routes.completeDelivery(id),
      Routes.failDelivery(id),
    ];
    final missing = <String>[];
    for (final screen in forms) {
      router.go(screen);
      await settle();
      var fields = 0;
      for (final decorator in tester.widgetList<InputDecorator>(find.byType(InputDecorator))) {
        fields++;
        // A dropdown that already shows a value doesn't need one.
        if ((decorator.decoration.hintText ?? '').isEmpty && decorator.isEmpty) missing.add(screen);
      }
      expect(fields, greaterThan(0), reason: '$screen has no fields');
    }
    expect(missing, isEmpty);
  });
}
