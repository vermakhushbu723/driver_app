import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/contact_launcher.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/photo_field.dart';
import '../domain/delivery_order.dart';
import 'order_providers.dart';
import 'order_screens.dart';

/// The Dashboard and My Orders sub-menus: one list of orders per filter.
enum OrderFilter {
  today('Today\'s deliveries'),
  pending('Pending deliveries'),
  completed('Completed deliveries'),
  assigned('Assigned orders'),
  accepted('Accepted orders'),
  pickedUp('Picked up orders'),
  outForDelivery('Out for delivery'),
  delivered('Delivered orders'),
  failed('Failed deliveries');

  const OrderFilter(this.title);

  final String title;

  bool matches(DeliveryOrder o, DateTime now) => switch (this) {
    OrderFilter.today => isSameDay(o.deliveryDate, now),
    OrderFilter.pending => o.isPending,
    OrderFilter.completed => o.status == DeliveryStatus.delivered && isSameDay(o.delivery?.at ?? o.deliveryDate, now),
    OrderFilter.assigned => o.status == DeliveryStatus.assigned,
    OrderFilter.accepted => o.status == DeliveryStatus.accepted,
    OrderFilter.pickedUp => o.status == DeliveryStatus.pickedUp,
    OrderFilter.outForDelivery => o.status == DeliveryStatus.outForDelivery,
    OrderFilter.delivered => o.status == DeliveryStatus.delivered,
    OrderFilter.failed => o.status == DeliveryStatus.failed,
  };
}

class OrderListScreen extends ConsumerWidget {
  const OrderListScreen({super.key, required this.filter});

  final OrderFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(filter.title)),
      body: AsyncBody(
        value: ref.watch(ordersProvider),
        onRetry: () => ref.invalidate(ordersProvider),
        builder: (orders) {
          final now = DateTime.now();
          final items = orders.where((o) => filter.matches(o, now)).toList();
          if (items.isEmpty) {
            return EmptyState(icon: Icons.local_shipping_outlined, title: 'No ${filter.title.toLowerCase()}');
          }
          return RefreshIndicator(
            onRefresh: () async => refreshOrders(ref),
            child: ListView.separated(
              padding: AppSpacing.page,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => OrderTile(order: items[i]),
            ),
          );
        },
      ),
    );
  }
}

/// The Delivery Management sub-menus.
enum DeliverySection {
  dealers('Dealer details', 'No dealers to deliver to right now.'),
  addresses('Delivery address', 'No delivery addresses right now.'),
  navigation('Google Maps navigation', 'No deliveries to navigate to right now.'),
  call('Call dealer', 'No dealers to call right now.'),
  quantity('Delivered quantity', 'Deliveries you are making or have made show up here.'),
  photos('Upload delivery photos', 'Deliveries you are making or have made show up here.'),
  receiver('Receiver name', 'Deliveries you are making or have made show up here.');

  const DeliverySection(this.title, this.emptyMessage);

  final String title;
  final String emptyMessage;

  /// Contact sections only need orders still to deliver; proof sections also cover finished ones.
  bool includes(DeliveryOrder o) {
    final active = o.status == DeliveryStatus.pickedUp || o.status == DeliveryStatus.outForDelivery;
    return switch (this) {
      DeliverySection.quantity ||
      DeliverySection.photos ||
      DeliverySection.receiver => active || o.status == DeliveryStatus.delivered,
      _ => o.status == DeliveryStatus.accepted || active,
    };
  }
}

class DeliverySectionScreen extends ConsumerWidget {
  const DeliverySectionScreen({super.key, required this.section});

  final DeliverySection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(section.title)),
      body: AsyncBody(
        value: ref.watch(ordersProvider),
        onRetry: () => ref.invalidate(ordersProvider),
        builder: (orders) {
          final items = orders.where(section.includes).toList();
          if (items.isEmpty) {
            return EmptyState(icon: Icons.local_shipping_outlined, title: section.title, message: section.emptyMessage);
          }
          return ListView.separated(
            padding: AppSpacing.page,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _DeliveryCard(section: section, order: items[i]),
          );
        },
      ),
    );
  }
}

class _DeliveryCard extends ConsumerWidget {
  const _DeliveryCard({required this.section, required this.order});

  final DeliverySection section;
  final DeliveryOrder order;

  Widget _openDeliveryButton(BuildContext context) => OutlinedButton(
    onPressed: () => context.push(
      order.status == DeliveryStatus.outForDelivery ? Routes.completeDelivery(order.id) : Routes.order(order.id),
    ),
    child: Text(order.status == DeliveryStatus.outForDelivery ? 'Complete delivery' : 'Open order'),
  );

  Future<void> _addPhoto(WidgetRef ref, BuildContext context) async {
    final photo = await capturePhoto(context, ref);
    if (photo == null || !context.mounted) return;
    final delivery = order.delivery!;
    await runOrderAction(
      context,
      ref,
      () => ref
          .read(orderRepositoryProvider)
          .updateDelivery(order.id, delivery.copyWith(photos: [...delivery.photos, photo])),
    );
  }

  Future<void> _editReceiver(WidgetRef ref, BuildContext context) async {
    final delivery = order.delivery!;
    final controller = TextEditingController(text: delivery.receivedBy);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Receiver name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: enterHint('Receiver name')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || !context.mounted) return;
    await runOrderAction(
      context,
      ref,
      () => ref.read(orderRepositoryProvider).updateDelivery(order.id, delivery.copyWith(receivedBy: name)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final delivered = order.status == DeliveryStatus.delivered;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(order.dealerName, style: text.titleSmall)),
              StatusChip(order.status.label, color: statusColor(order.status)),
            ],
          ),
          Text(order.number, style: text.bodySmall),
          const SizedBox(height: 6),
          ...switch (section) {
            DeliverySection.dealers => [
              InfoRow('Phone', order.dealerPhone),
              InfoRow('Address', order.address),
              InfoRow('Payment', order.payment.label),
              if (order.collectsPayment) InfoRow('To collect', money(order.orderValue)),
              InfoRow('Slot', order.slot),
              if (order.notes.isNotEmpty) InfoRow('Note', order.notes),
              const SizedBox(height: 6),
              OutlinedButton(onPressed: () => context.push(Routes.order(order.id)), child: const Text('Open order')),
            ],
            DeliverySection.addresses => [
              Text(order.address),
              if (order.notes.isNotEmpty) Text('Note: ${order.notes}', style: text.labelMedium),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: order.address));
                  showMessage(context, 'Address copied');
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy address'),
              ),
            ],
            DeliverySection.navigation => [
              Text(order.address),
              const SizedBox(height: 6),
              FilledButton.icon(
                onPressed: () => ContactLauncher.navigateTo(order.address),
                icon: const Icon(Icons.navigation_outlined),
                label: const Text('Navigate in Google Maps'),
              ),
            ],
            DeliverySection.call => [
              Text(order.dealerPhone),
              const SizedBox(height: 6),
              FilledButton.icon(
                onPressed: () => ContactLauncher.call(order.dealerPhone),
                icon: const Icon(Icons.call_outlined),
                label: const Text('Call dealer'),
              ),
            ],
            DeliverySection.quantity => [
              for (final i in order.items)
                InfoRow(
                  '${i.name} (${i.packSize})',
                  delivered
                      ? '${order.delivery!.delivered[i.id] ?? 0} of ${i.quantity} ${i.unit}'
                      : '${order.loadedOf(i)} ${i.unit} loaded',
                ),
              if (!delivered) ...[const SizedBox(height: 6), _openDeliveryButton(context)],
            ],
            DeliverySection.photos => [
              if (delivered) ...[
                PhotoGallery(photos: order.delivery!.photos),
                OutlinedButton.icon(
                  onPressed: () => _addPhoto(ref, context),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Add delivery photo'),
                ),
              ] else ...[
                const Text('Delivery photos are taken when you complete the delivery.'),
                const SizedBox(height: 6),
                _openDeliveryButton(context),
              ],
            ],
            DeliverySection.receiver => [
              if (delivered) ...[
                InfoRow(
                  'Receiver',
                  order.delivery!.receivedBy.isEmpty ? 'Not given' : order.delivery!.receivedBy,
                  valueColor: order.delivery!.receivedBy.isEmpty ? AppColors.neutral500 : null,
                ),
                OutlinedButton(onPressed: () => _editReceiver(ref, context), child: const Text('Edit name')),
              ] else ...[
                const Text('The name is optional, and is entered when you complete the delivery.'),
                const SizedBox(height: 6),
                _openDeliveryButton(context),
              ],
            ],
          },
        ],
      ),
    );
  }
}

class DeliveryHistoryScreen extends ConsumerStatefulWidget {
  const DeliveryHistoryScreen({super.key});

  @override
  ConsumerState<DeliveryHistoryScreen> createState() => _DeliveryHistoryScreenState();
}

class _DeliveryHistoryScreenState extends ConsumerState<DeliveryHistoryScreen> {
  String _query = '';
  DateTimeRange? _range;

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  bool _inRange(DeliveryOrder o) {
    final range = _range;
    if (range == null) return true;
    return !o.deliveryDate.isBefore(range.start) && o.deliveryDate.isBefore(range.end.add(const Duration(days: 1)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery history'),
        actions: [IconButton(tooltip: 'Filter by date', icon: const Icon(Icons.date_range), onPressed: _pickRange)],
      ),
      body: AsyncBody(
        value: ref.watch(ordersProvider),
        builder: (orders) {
          final query = _query.trim().toLowerCase();
          final done = orders.where((o) => o.isDone && _inRange(o)).toList();
          final items = done.where((o) => '${o.number} ${o.dealerName}'.toLowerCase().contains(query)).toList();
          final delivered = done.where((o) => o.status == DeliveryStatus.delivered).length;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 12, 13, 0),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search by order ID or dealer',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 8, 13, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$delivered delivered · ${done.length - delivered} failed',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    if (_range != null)
                      InputChip(
                        label: Text('${formatDate(_range!.start)} - ${formatDate(_range!.end)}'),
                        onDeleted: () => setState(() => _range = null),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? const EmptyState(icon: Icons.history, title: 'No deliveries found')
                    : ListView.separated(
                        padding: AppSpacing.page,
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => OrderTile(order: items[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
