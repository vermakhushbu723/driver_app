import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../data/api_return_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/location/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/photo_field.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../orders/domain/delivery_order.dart';
import '../../orders/presentation/order_providers.dart';
import '../data/fake_return_repository.dart';
import '../domain/return_report.dart';

final returnRepositoryProvider = Provider<ReturnRepository>(
  (ref) => useFakeBackend ? FakeReturnRepository(ref.watch(riderStoreProvider), ref.watch(notificationRepositoryProvider)) : ApiReturnRepository(ref.watch(apiProvider)),
);

final returnReportsProvider = FutureProvider<List<ReturnReport>>(
  (ref) => ref.watch(returnRepositoryProvider).reports(),
);

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final ReturnReport report;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${report.quantity} units · ${report.dealerName}', style: Theme.of(context).textTheme.labelLarge),
            Text(report.orderNumber),
            Text(formatDateTime(report.at), style: Theme.of(context).textTheme.bodySmall),
            if (report.note.isNotEmpty) Text(report.note),
            if (report.location != null)
              Text('GPS ${report.location!.label}', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            PhotoGallery(photos: report.photos),
          ],
        ),
      ),
    );
  }
}

/// The reports of one type, with a button to add another.
class ReturnListScreen extends ConsumerWidget {
  const ReturnListScreen({super.key, required this.type});

  final ReturnType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(type.label)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.newReturn(type.name)),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Report'),
      ),
      body: AsyncBody(
        value: ref.watch(returnReportsProvider),
        onRetry: () => ref.invalidate(returnReportsProvider),
        builder: (reports) {
          final items = reports.where((r) => r.type == type).toList();
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.assignment_return_outlined,
              title: 'No ${type.label.toLowerCase()} reported',
              message: 'Report stock you bring back to the factory.',
            );
          }
          return ListView(
            padding: AppSpacing.pageWithFab,
            children: [for (final r in items) _ReportCard(report: r)],
          );
        },
      ),
    );
  }
}

class ReturnPhotosScreen extends ConsumerWidget {
  const ReturnPhotosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Return photos')),
      body: AsyncBody(
        value: ref.watch(returnReportsProvider),
        builder: (reports) {
          final withPhotos = reports.where((r) => r.photos.isNotEmpty).toList();
          if (withPhotos.isEmpty) {
            return const EmptyState(icon: Icons.photo_library_outlined, title: 'No return photos yet');
          }
          return ListView(
            padding: AppSpacing.page,
            children: [
              for (final r in withPhotos) ...[SectionTitle(r.type.label), _ReportCard(report: r)],
            ],
          );
        },
      ),
    );
  }
}

class NewReturnScreen extends ConsumerStatefulWidget {
  const NewReturnScreen({super.key, required this.type});

  final ReturnType type;

  @override
  ConsumerState<NewReturnScreen> createState() => _NewReturnScreenState();
}

class _NewReturnScreenState extends ConsumerState<NewReturnScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _note = TextEditingController();
  String? _orderId;
  List<CapturedPhoto> _photos = const [];
  bool _saving = false;

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit(List<DeliveryOrder> orders) async {
    if (!_formKey.currentState!.validate()) return;
    if (_photos.isEmpty) {
      showMessage(context, 'Please take a photo of the stock', isError: true);
      return;
    }
    final order = orders.firstWhere((o) => o.id == _orderId);
    setState(() => _saving = true);
    final location = await ref.read(locateProvider)();
    final now = DateTime.now();
    await ref
        .read(returnRepositoryProvider)
        .submit(
          ReturnReport(
            id: 'ret-${now.microsecondsSinceEpoch}',
            type: widget.type,
            orderId: order.id,
            orderNumber: order.number,
            dealerName: order.dealerName,
            quantity: int.parse(_quantity.text),
            note: _note.text.trim(),
            photos: _photos,
            at: now,
            location: location,
          ),
        );
    ref.invalidate(returnReportsProvider);
    ref.invalidate(notificationsProvider);
    if (!mounted) return;
    showMessage(context, 'Report sent');
    context.pop();
  }

  String? _validateQuantity(String? v, List<DeliveryOrder> orders) {
    final quantity = int.tryParse(v ?? '');
    if (quantity == null || quantity < 1) return 'Enter the number of units';
    final order = orders.where((o) => o.id == _orderId).firstOrNull;
    if (order != null && quantity > order.totalUnits) return 'This order has only ${order.totalUnits} units';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Report ${widget.type.label.toLowerCase()}')),
      body: AsyncBody(
        value: ref.watch(ordersProvider),
        builder: (all) {
          final orders = all
              .where(
                (o) => o.pickup != null || o.status == DeliveryStatus.delivered || o.status == DeliveryStatus.failed,
              )
              .toList();
          if (orders.isEmpty) {
            return const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No orders to report on',
              message: 'Reports are linked to an order you have loaded or delivered.',
            );
          }
          return Form(
            key: _formKey,
            child: ListView(
              padding: AppSpacing.page,
              children: [
                LabeledField(
                  label: 'Select order',
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    style: Theme.of(context).textTheme.bodyLarge,
                    initialValue: _orderId,
                    decoration: InputDecoration(hintText: selectHint('Select order')),
                    items: [
                      for (final o in orders)
                        DropdownMenuItem(
                          value: o.id,
                          child: Text('${o.number} · ${o.dealerName}', overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    validator: (v) => v == null ? 'Select the order this is about' : null,
                    onChanged: (v) => setState(() => _orderId = v),
                  ),
                ),
                const SizedBox(height: 12),
                LabeledField(
                  label: 'Number of units',
                  child: TextFormField(
                    controller: _quantity,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => _validateQuantity(v, orders),
                    decoration: InputDecoration(hintText: enterHint('Number of units')),
                  ),
                ),
                const SizedBox(height: 12),
                LabeledField(
                  label: 'Details',
                  child: TextFormField(
                    controller: _note,
                    maxLines: 2,
                    validator: Validators.required,
                    decoration: InputDecoration(hintText: enterHint('Details')),
                  ),
                ),
                const SectionTitle('Return photos'),
                PhotoField(photos: _photos, onChanged: (p) => setState(() => _photos = p)),
                const SizedBox(height: 12),
                LoadingButton(label: 'Send report', loading: _saving, onPressed: () => _submit(orders)),
              ],
            ),
          );
        },
      ),
    );
  }
}
