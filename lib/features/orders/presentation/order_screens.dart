import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/location/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/contact_launcher.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/photo_field.dart';
import '../domain/delivery_order.dart';
import 'order_providers.dart';

Color statusColor(DeliveryStatus status) => switch (status) {
  DeliveryStatus.delivered => AppColors.green600,
  DeliveryStatus.failed => AppColors.red600,
  DeliveryStatus.outForDelivery => AppColors.amber600,
  _ => AppColors.sky700,
};

/// Runs [action], then refreshes, and shows any error instead of throwing.
Future<bool> runOrderAction(BuildContext context, WidgetRef ref, Future<void> Function() action) async {
  try {
    await action();
    refreshOrders(ref);
    return true;
  } catch (e) {
    refreshOrders(ref);
    if (context.mounted) showMessage(context, '$e', isError: true);
    return false;
  }
}

class OrderTile extends StatelessWidget {
  const OrderTile({super.key, required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      onTap: () => context.push(Routes.order(order.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(order.dealerName, style: text.titleSmall)),
              StatusChip(order.status.label, color: statusColor(order.status)),
            ],
          ),
          const SizedBox(height: 4),
          Text(order.address, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text('${order.number} · ${order.totalUnits} units', style: text.bodySmall),
          Text('${formatDateShort(order.deliveryDate)} · ${order.slot}', style: text.bodySmall),
          if (order.collectsPayment && order.isPending) ...[
            const SizedBox(height: 4),
            Text('Collect ${money(order.orderValue)}', style: text.labelLarge?.copyWith(color: AppColors.amber600)),
          ],
        ],
      ),
    );
  }
}

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  static const _tabs = [
    ('Assigned', DeliveryStatus.assigned),
    ('Accepted', DeliveryStatus.accepted),
    ('Picked up', DeliveryStatus.pickedUp),
    ('Out for delivery', DeliveryStatus.outForDelivery),
    ('Delivered', DeliveryStatus.delivered),
    ('Failed', DeliveryStatus.failed),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My orders'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.sky700,
            indicatorColor: AppColors.sky700,
            tabs: [for (final (label, _) in _tabs) Tab(text: label)],
          ),
        ),
        body: AsyncBody(
          value: ref.watch(ordersProvider),
          onRetry: () => ref.invalidate(ordersProvider),
          builder: (orders) => TabBarView(
            children: [
              for (final (label, status) in _tabs)
                _OrderList(orders: orders.where((o) => o.status == status).toList(), tabLabel: label),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderList extends ConsumerWidget {
  const _OrderList({required this.orders, required this.tabLabel});

  final List<DeliveryOrder> orders;
  final String tabLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orders.isEmpty) {
      return EmptyState(icon: Icons.local_shipping_outlined, title: 'No orders in ${tabLabel.toLowerCase()}');
    }
    return RefreshIndicator(
      onRefresh: () async => refreshOrders(ref),
      child: ListView.separated(
        padding: AppSpacing.page,
        itemCount: orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => OrderTile(order: orders[i]),
      ),
    );
  }
}

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  static const _rejectReasons = ['Vehicle problem', 'Already at capacity', 'Outside my zone', 'Not available'];

  Future<void> _reject(BuildContext context, WidgetRef ref, DeliveryOrder order) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text('Why can\'t you take this order?', style: Theme.of(context).textTheme.titleSmall)),
            for (final r in _rejectReasons) ListTile(title: Text(r), onTap: () => Navigator.pop(context, r)),
          ],
        ),
      ),
    );
    if (reason == null || !context.mounted) return;
    final done = await runOrderAction(context, ref, () => ref.read(orderRepositoryProvider).reject(order.id, reason));
    if (done && context.mounted) context.go(Routes.orders);
  }

  Widget _actions(BuildContext context, WidgetRef ref, DeliveryOrder order) {
    final repo = ref.read(orderRepositoryProvider);
    return switch (order.status) {
      DeliveryStatus.assigned => Row(
        children: [
          Expanded(
            child: OutlinedButton(onPressed: () => _reject(context, ref, order), child: const Text('Reject')),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              onPressed: () => runOrderAction(context, ref, () => repo.accept(order.id)),
              child: const Text('Accept order'),
            ),
          ),
        ],
      ),
      DeliveryStatus.accepted => FilledButton.icon(
        onPressed: () => context.push(Routes.loading(order.id)),
        icon: const Icon(Icons.inventory_2_outlined),
        label: const Text('Confirm loading at factory'),
      ),
      DeliveryStatus.pickedUp => FilledButton.icon(
        onPressed: () => runOrderAction(context, ref, () => repo.startDelivery(order.id)),
        icon: const Icon(Icons.local_shipping_outlined),
        label: const Text('Start delivery'),
      ),
      DeliveryStatus.outForDelivery => FilledButton.icon(
        onPressed: () => context.push(Routes.completeDelivery(order.id)),
        icon: const Icon(Icons.check_circle_outline),
        label: const Text('Complete delivery'),
      ),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(orderProvider(orderId));
    final order = value.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Order details')),
      bottomNavigationBar: order == null || order.isDone
          ? null
          : SafeArea(
              child: Padding(padding: const EdgeInsets.fromLTRB(13, 8, 13, 8), child: _actions(context, ref, order)),
            ),
      body: AsyncBody(
        value: value,
        builder: (order) {
          if (order == null) return const EmptyState(icon: Icons.receipt_long_outlined, title: 'Order not found');
          final text = Theme.of(context).textTheme;
          return ListView(
            padding: AppSpacing.page,
            children: [
              Row(
                children: [
                  Expanded(child: Text(order.number, style: text.titleMedium)),
                  StatusChip(order.status.label, color: statusColor(order.status)),
                ],
              ),
              const SectionTitle('Dealer'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(order.dealerName, style: text.titleSmall),
                    Text(order.address),
                    if (order.notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Note: ${order.notes}', style: text.labelMedium),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => ContactLauncher.call(order.dealerPhone),
                            icon: const Icon(Icons.call_outlined),
                            label: const Text('Call'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => ContactLauncher.navigateTo(order.address),
                            icon: const Icon(Icons.navigation_outlined),
                            label: const Text('Navigate'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SectionTitle('Items'),
              AppCard(
                child: Column(
                  children: [
                    for (final i in order.items)
                      InfoRow(
                        '${i.name} (${i.packSize})',
                        order.delivery != null
                            ? '${order.delivery!.delivered[i.id] ?? 0} of ${i.quantity} ${i.unit} delivered'
                            : order.pickup != null
                            ? '${order.loadedOf(i)} of ${i.quantity} ${i.unit} loaded'
                            : '${i.quantity} ${i.unit}',
                      ),
                  ],
                ),
              ),
              const SectionTitle('Delivery'),
              AppCard(
                child: Column(
                  children: [
                    InfoRow('Date', formatDateShort(order.deliveryDate)),
                    InfoRow('Slot', order.slot),
                    InfoRow('Payment', order.payment.label),
                    if (order.collectsPayment) InfoRow('Order value', money(order.orderValue)),
                  ],
                ),
              ),
              if (order.pickup != null) ...[
                const SectionTitle('Loading'),
                AppCard(
                  child: Column(
                    children: [
                      InfoRow('Loaded at', formatDateTime(order.pickup!.at)),
                      if (order.pickup!.remark.isNotEmpty) InfoRow('Remark', order.pickup!.remark),
                      if (order.pickup!.location != null) InfoRow('GPS', order.pickup!.location!.label),
                      PhotoGallery(photos: order.pickup!.photos),
                    ],
                  ),
                ),
              ],
              if (order.delivery != null) ...[
                const SectionTitle('Proof of delivery'),
                AppCard(
                  child: Column(
                    children: [
                      InfoRow('Delivered at', formatDateTime(order.delivery!.at)),
                      if (order.delivery!.receivedBy.isNotEmpty) InfoRow('Received by', order.delivery!.receivedBy),
                      if (order.delivery!.remark.isNotEmpty) InfoRow('Remark', order.delivery!.remark),
                      if (order.delivery!.location != null) InfoRow('GPS', order.delivery!.location!.label),
                      if (order.delivery!.collectionMode != null)
                        InfoRow(
                          'Collected',
                          '${money(order.delivery!.collected)} by ${order.delivery!.collectionMode!.label}',
                        ),
                      PhotoGallery(photos: order.delivery!.photos),
                    ],
                  ),
                ),
              ],
              if (order.failure != null) ...[
                const SizedBox(height: 12),
                NoticeBanner('Failed: ${order.failure!.reason}. ${order.failure!.note}', color: AppColors.red600),
                const SizedBox(height: 8),
                InfoRow('Time', formatDateTime(order.failure!.at)),
                if (order.failure!.location != null) InfoRow('GPS', order.failure!.location!.label),
                PhotoGallery(photos: order.failure!.photos),
              ],
              if (order.canFail) ...[
                const SizedBox(height: 12),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppColors.red600),
                  onPressed: () => context.push(Routes.failDelivery(order.id)),
                  child: const Text('Could not deliver'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class CompleteDeliveryScreen extends ConsumerStatefulWidget {
  const CompleteDeliveryScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<CompleteDeliveryScreen> createState() => _CompleteDeliveryScreenState();
}

class _CompleteDeliveryScreenState extends ConsumerState<CompleteDeliveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otp = TextEditingController();
  final _receivedBy = TextEditingController();
  final _remark = TextEditingController();
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  Map<String, int>? _delivered;
  List<CapturedPhoto> _photos = const [];
  CollectionMode _mode = CollectionMode.cash;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_otp, _receivedBy, _remark, _amount, _reference]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _isShort(DeliveryOrder order) => order.items.any((i) => (_delivered![i.id] ?? 0) < i.quantity);

  Future<void> _submit(DeliveryOrder order) async {
    if (!_formKey.currentState!.validate()) return;
    if (_photos.isEmpty) {
      showMessage(context, 'Please take a photo of the delivered goods', isError: true);
      return;
    }
    setState(() => _saving = true);
    final location = await ref.read(locateProvider)();
    if (!mounted) return;
    final collected = order.collectsPayment ? double.parse(_amount.text.trim()) : 0.0;
    final done = await runOrderAction(
      context,
      ref,
      () => ref
          .read(orderRepositoryProvider)
          .completeDelivery(
            order.id,
            _otp.text,
            DeliveryRecord(
              delivered: _delivered!,
              receivedBy: _receivedBy.text.trim(),
              photos: _photos,
              at: DateTime.now(),
              remark: _remark.text.trim(),
              location: location,
              collected: collected,
              collectionMode: order.collectsPayment ? _mode : null,
              collectionReference: _reference.text.trim(),
            ),
          ),
    );
    if (!mounted) return;
    if (done) {
      showMessage(context, 'Delivery completed');
      context.pop();
    } else {
      setState(() => _saving = false);
    }
  }

  String? _validateAmount(String? v, double due) {
    final problem = Validators.positiveAmount(v);
    if (problem != null) return problem;
    return double.parse(v!.trim()) > due ? 'This is more than the ${money(due)} due' : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete delivery')),
      body: AsyncBody(
        value: ref.watch(orderProvider(widget.orderId)),
        builder: (order) {
          if (order == null) return const EmptyState(icon: Icons.receipt_long_outlined, title: 'Order not found');
          _delivered ??= {for (final i in order.items) i.id: order.loadedOf(i)};
          final due = order.amountDue(_delivered!);
          return Form(
            key: _formKey,
            child: ListView(
              padding: AppSpacing.page,
              children: [
                const SectionTitle('Quantity delivered'),
                for (final i in order.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(child: Text('${i.name} (${i.packSize})\nLoaded ${order.loadedOf(i)} ${i.unit}')),
                          QuantityStepper(
                            value: _delivered![i.id]!,
                            min: 0,
                            max: order.loadedOf(i),
                            onChanged: (v) => setState(() => _delivered![i.id] = v),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_isShort(order)) ...[
                  LabeledField(
                    label: 'Why is the quantity short?',
                    child: TextFormField(
                      controller: _remark,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Say why the quantity is short' : null,
                      decoration: InputDecoration(hintText: enterHint('Why is the quantity short?')),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (order.collectsPayment) ...[
                  const SectionTitle('Collect payment'),
                  InfoRow('Amount due', money(due), bold: true),
                  const SizedBox(height: 8),
                  SegmentedButton<CollectionMode>(
                    segments: [for (final m in CollectionMode.values) ButtonSegment(value: m, label: Text(m.label))],
                    selected: {_mode},
                    onSelectionChanged: (s) => setState(() => _mode = s.first),
                  ),
                  const SizedBox(height: 12),
                  LabeledField(
                    label: 'Amount collected',
                    child: TextFormField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      validator: (v) => _validateAmount(v, due),
                      decoration: InputDecoration(
                        hintText: enterHint('Amount collected'),
                        prefixIcon: fieldPrefix('₹'),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _amount.text = due.toStringAsFixed(2),
                      child: const Text('Collected in full'),
                    ),
                  ),
                  if (_mode == CollectionMode.upi) ...[
                    LabeledField(
                      label: 'UPI transaction ID',
                      child: TextFormField(
                        controller: _reference,
                        validator: Validators.required,
                        decoration: InputDecoration(hintText: enterHint('UPI transaction ID')),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
                const SectionTitle('Proof of delivery'),
                LabeledField(
                  label: 'Receiver name (optional)',
                  child: TextFormField(
                    controller: _receivedBy,
                    decoration: InputDecoration(hintText: enterHint('Receiver name (optional)')),
                  ),
                ),
                const SizedBox(height: 12),
                PhotoField(photos: _photos, onChanged: (p) => setState(() => _photos = p)),
                const SizedBox(height: 12),
                LabeledField(
                  label: 'Delivery OTP from the dealer',
                  child: TextFormField(
                    controller: _otp,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => v?.length == 4 ? null : 'Enter the 4-digit delivery OTP',
                    decoration: InputDecoration(hintText: enterHint('Delivery OTP from the dealer'), counterText: ''),
                  ),
                ),
                const SizedBox(height: 8),
                NoticeBanner(
                  'Demo: the OTP for this order is ${order.deliveryOtp}. Riders won\'t see it once the dealer app is connected.',
                ),
                const SizedBox(height: 12),
                LoadingButton(label: 'Confirm delivery', loading: _saving, onPressed: () => _submit(order)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class FailDeliveryScreen extends ConsumerStatefulWidget {
  const FailDeliveryScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<FailDeliveryScreen> createState() => _FailDeliveryScreenState();
}

class _FailDeliveryScreenState extends ConsumerState<FailDeliveryScreen> {
  static const _reasons = [
    'Shop closed',
    'Dealer not reachable',
    'Dealer refused the order',
    'Wrong address',
    'Vehicle breakdown',
    'Ice melted or damaged',
    'Other',
  ];

  final _note = TextEditingController();
  String? _reason;
  List<CapturedPhoto> _photos = const [];
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null) {
      showMessage(context, 'Please choose a reason', isError: true);
      return;
    }
    if (_reason == 'Other' && _note.text.trim().isEmpty) {
      showMessage(context, 'Please describe what happened', isError: true);
      return;
    }
    setState(() => _saving = true);
    final location = await ref.read(locateProvider)();
    if (!mounted) return;
    final done = await runOrderAction(
      context,
      ref,
      () => ref
          .read(orderRepositoryProvider)
          .markFailed(
            widget.orderId,
            FailureRecord(
              reason: _reason!,
              at: DateTime.now(),
              note: _note.text.trim(),
              photos: _photos,
              location: location,
            ),
          ),
    );
    if (!mounted) return;
    done ? context.pop() : setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Could not deliver')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          const SectionTitle('What happened?'),
          RadioGroup<String>(
            groupValue: _reason,
            onChanged: (r) => setState(() => _reason = r),
            child: Column(
              children: [
                for (final r in _reasons)
                  RadioListTile<String>(value: r, contentPadding: EdgeInsets.zero, title: Text(r)),
              ],
            ),
          ),
          LabeledField(
            label: 'More details',
            child: TextField(
              controller: _note,
              maxLines: 2,
              decoration: InputDecoration(hintText: enterHint('More details')),
            ),
          ),
          const SectionTitle('Photos (optional)'),
          PhotoField(photos: _photos, onChanged: (p) => setState(() => _photos = p)),
          const SizedBox(height: 12),
          LoadingButton(label: 'Mark as failed', loading: _saving, onPressed: _submit),
        ],
      ),
    );
  }
}
