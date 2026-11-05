import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../collection/presentation/collection_screens.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../orders/domain/delivery_order.dart';
import '../../orders/presentation/order_providers.dart';
import '../../orders/presentation/delivery_screens.dart';
import '../../orders/presentation/order_screens.dart';
import '../../tracking/presentation/tracking_screens.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rider = ref.watch(authControllerProvider).value;
    final orders = ref.watch(ordersProvider).value ?? const <DeliveryOrder>[];
    final summary = ref.watch(collectionSummaryProvider).value;
    final now = DateTime.now();

    final today = orders.where((o) => isSameDay(o.deliveryDate, now)).toList();
    final pending = orders.where((o) => o.isPending).toList();
    final completed = today.where((o) => o.status == DeliveryStatus.delivered).length;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Image.asset(AppConstants.logo, height: 38),
        centerTitle: false,
        actions: const [NotificationBell()],
      ),
      body: RefreshIndicator(
        onRefresh: () async => refreshOrders(ref),
        child: ListView(
          padding: AppSpacing.page,
          children: [
            Text('Hello, ${rider?.name ?? ''}', style: text.headlineMedium),
            if (rider != null) Text('${rider.vehicleNumber} · ${rider.zone}'),
            const SizedBox(height: 8),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(rider?.onDuty ?? false ? 'On duty' : 'Off duty', style: text.titleSmall),
                subtitle: Text(rider?.onDuty ?? false ? 'You can receive new orders' : 'You won\'t receive new orders'),
                value: rider?.onDuty ?? false,
                onChanged: (on) => setDuty(ref, on),
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.0,
              children: [
                _StatTile(
                  Icons.today_outlined,
                  'Today\'s deliveries',
                  '${today.length}',
                  () => context.push(Routes.orderList(OrderFilter.today.name)),
                ),
                _StatTile(
                  Icons.pending_actions,
                  'Pending deliveries',
                  '${pending.length}',
                  () => context.push(Routes.orderList(OrderFilter.pending.name)),
                ),
                _StatTile(
                  Icons.check_circle_outline,
                  'Completed deliveries',
                  '$completed',
                  () => context.push(Routes.orderList(OrderFilter.completed.name)),
                ),
                _StatTile(
                  Icons.payments_outlined,
                  'Today\'s collection',
                  money(summary?.totalOn(now) ?? 0),
                  () => context.go(Routes.collection),
                ),
              ],
            ),
            const SectionTitle('Next deliveries'),
            if (pending.isEmpty) const Text('No pending deliveries.'),
            for (final order in pending.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OrderTile(order: order),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.icon, this.label, this.value, this.onTap);

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.sky700),
              const SizedBox(width: 6),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: text.titleLarge),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.labelSmall),
        ],
      ),
    );
  }
}
