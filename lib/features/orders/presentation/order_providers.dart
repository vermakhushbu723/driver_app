import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../data/api_order_repository.dart';

import '../../auth/presentation/auth_providers.dart';
import '../../collection/presentation/collection_screens.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../data/fake_order_repository.dart';
import '../domain/delivery_order.dart';

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => !useFakeBackend ? ApiOrderRepository(ref.watch(apiProvider)) : FakeOrderRepository(
    ref.watch(riderStoreProvider),
    ref.watch(collectionRepositoryProvider),
    ref.watch(notificationRepositoryProvider),
  ),
);

final ordersProvider = FutureProvider<List<DeliveryOrder>>((ref) async {
  final orders = await ref.watch(orderRepositoryProvider).orders();
  // The first read of a day adds new orders, which also notifies the rider.
  ref.invalidate(notificationsProvider);
  return orders;
});

final orderProvider = FutureProvider.family<DeliveryOrder?, String>((ref, id) async {
  final orders = await ref.watch(ordersProvider.future);
  return orders.where((o) => o.id == id).firstOrNull;
});

/// Call after anything that changes an order or the money collected.
void refreshOrders(WidgetRef ref) {
  ref.invalidate(ordersProvider);
  ref.invalidate(collectionSummaryProvider);
  ref.invalidate(notificationsProvider);
}
