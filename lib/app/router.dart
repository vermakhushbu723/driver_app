import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/attendance/presentation/attendance_screens.dart';
import '../features/auth/domain/rider.dart';
import '../features/auth/presentation/auth_providers.dart';
import '../features/auth/presentation/login_screens.dart';
import '../features/collection/presentation/collection_screens.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/orders/domain/delivery_order.dart';
import '../features/orders/presentation/delivery_screens.dart';
import '../features/orders/presentation/order_screens.dart';
import '../features/pickup/presentation/pickup_screens.dart';
import '../features/profile/presentation/menu_screens.dart';
import '../features/returns/domain/return_report.dart';
import '../features/returns/presentation/return_screens.dart';
import '../features/support/presentation/support_screens.dart';
import '../features/tracking/presentation/tracking_screens.dart';
import 'app_shell.dart';
import 'routes.dart';

final _rootKey = GlobalKey<NavigatorState>();

String? _redirect(AsyncValue<Rider?> auth, String location) {
  if (auth.isLoading && !auth.hasValue) return location == Routes.splash ? null : Routes.splash;
  const signedOutScreens = [Routes.login, Routes.otp];
  if (auth.value == null) return signedOutScreens.contains(location) ? null : Routes.login;
  return signedOutScreens.contains(location) || location == Routes.splash ? Routes.home : null;
}

GoRoute _page(String path, Widget Function(GoRouterState state) builder) =>
    GoRoute(path: path, parentNavigatorKey: _rootKey, builder: (_, state) => builder(state));

StatefulShellBranch _tab(String path, Widget screen, {List<RouteBase> routes = const []}) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (_, _) => screen, routes: routes)],
);

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);
  // The page a link or a browser reload asked for, while the app still checks the session.
  String? wanted;

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (_, state) {
      var target = _redirect(ref.read(authControllerProvider), state.matchedLocation);
      if (target == Routes.splash) wanted = state.uri.toString();
      // Once signed in, open that page instead of the dashboard.
      if (target == Routes.home && wanted != null) (target, wanted) = (wanted, null);
      // The OTP screen needs its phone number, which a page reload on the web loses.
      if (target == null && state.matchedLocation == Routes.otp && state.extra == null) return Routes.login;
      return target;
    },
    routes: [
      _page(Routes.splash, (_) => const SplashScreen()),
      _page(Routes.login, (_) => const LoginScreen()),
      _page(Routes.otp, (state) => OtpScreen(phone: state.extra as String)),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          _tab(Routes.home, const DashboardScreen()),
          _tab(
            Routes.orders,
            const OrdersScreen(),
            routes: [
              GoRoute(
                path: ':id',
                parentNavigatorKey: _rootKey,
                builder: (_, state) => OrderDetailScreen(orderId: state.pathParameters['id']!),
              ),
            ],
          ),
          _tab(Routes.pickup, const PickupScreen()),
          _tab(Routes.collection, const CollectionScreen()),
          _tab(Routes.menu, const MenuScreen()),
        ],
      ),
      _page(
        '/order-list/:filter',
        (state) => OrderListScreen(filter: OrderFilter.values.byName(state.pathParameters['filter']!)),
      ),
      _page('/loading/:id', (state) => LoadingScreen(orderId: state.pathParameters['id']!)),
      _page('/complete-delivery/:id', (state) => CompleteDeliveryScreen(orderId: state.pathParameters['id']!)),
      _page('/fail-delivery/:id', (state) => FailDeliveryScreen(orderId: state.pathParameters['id']!)),
      _page(Routes.factoryDetails, (_) => const FactoryDetailsScreen()),
      _page(Routes.pickupQuantity, (_) => const PickupQuantityScreen()),
      _page(Routes.loadingConfirmation, (_) => const LoadingConfirmationListScreen()),
      _page(Routes.pickupPhotos, (_) => const PickupPhotosScreen()),
      _page(
        '/delivery/:section',
        (state) => DeliverySectionScreen(section: DeliverySection.values.byName(state.pathParameters['section']!)),
      ),
      _page(Routes.duty, (_) => const DutyScreen()),
      _page(Routes.liveGps, (_) => const LiveGpsScreen()),
      _page(Routes.routeTracking, (_) => const RouteTrackingScreen()),
      _page(Routes.cashCollection, (_) => const CollectionModeScreen(mode: CollectionMode.cash)),
      _page(Routes.upiCollection, (_) => const CollectionModeScreen(mode: CollectionMode.upi)),
      _page(Routes.paymentHistory, (_) => const PaymentHistoryScreen()),
      _page(Routes.cashHandover, (_) => const CashHandoverScreen()),
      _page(
        '/returns/:type',
        (state) => ReturnListScreen(type: ReturnType.values.byName(state.pathParameters['type']!)),
      ),
      _page(
        '/new-return/:type',
        (state) => NewReturnScreen(type: ReturnType.values.byName(state.pathParameters['type']!)),
      ),
      _page(Routes.returnPhotos, (_) => const ReturnPhotosScreen()),
      _page(Routes.deliveryHistory, (_) => const DeliveryHistoryScreen()),
      _page(Routes.collectionHistory, (_) => const CollectionHistoryScreen()),
      _page(Routes.attendance, (_) => const AttendanceScreen()),
      _page(Routes.salary, (_) => const SalaryScreen()),
      _page(Routes.incentives, (_) => const IncentivesScreen()),
      _page(Routes.notifications, (_) => const NotificationsScreen()),
      _page(Routes.notificationSettings, (_) => const NotificationSettingsScreen()),
      _page(Routes.support, (_) => const SupportScreen()),
      _page(Routes.tickets, (_) => const TicketsScreen()),
      _page('${Routes.tickets}/:id', (state) => TicketDetailScreen(ticketId: state.pathParameters['id']!)),
      _page(Routes.newTicket, (state) => NewTicketScreen(orderNumber: state.extra as String?)),
      _page(Routes.profile, (_) => const ProfileScreen()),
      _page(Routes.vehicle, (_) => const VehicleScreen()),
      _page(Routes.documents, (_) => const DocumentsScreen()),
      _page(Routes.changePassword, (_) => const ChangePasswordScreen()),
    ],
  );
});
