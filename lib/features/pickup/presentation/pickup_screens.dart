import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../data/api_factory_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/location/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/contact_launcher.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/photo_field.dart';
import '../../orders/domain/delivery_order.dart';
import '../../orders/presentation/order_providers.dart';
import '../../orders/presentation/order_screens.dart';
import '../data/fake_factory_repository.dart';
import '../domain/factory_info.dart';

final factoryRepositoryProvider = Provider<FactoryRepository>((ref) => useFakeBackend ? FakeFactoryRepository() : ApiFactoryRepository(ref.watch(apiProvider)));

final factoryProvider = FutureProvider<FactoryInfo>((ref) => ref.watch(factoryRepositoryProvider).assignedFactory());

class _FactoryCard extends StatelessWidget {
  const _FactoryCard({required this.factory});

  final FactoryInfo factory;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(factory.name, style: Theme.of(context).textTheme.titleSmall),
          Text(factory.address),
          const SizedBox(height: 6),
          InfoRow('Contact', factory.contactName),
          InfoRow('Loading hours', factory.loadingHours),
          const SizedBox(height: 4),
          Text(factory.instructions, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ContactLauncher.call(factory.phone),
                  icon: const Icon(Icons.call_outlined),
                  label: const Text('Call'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ContactLauncher.navigateTo(factory.address),
                  icon: const Icon(Icons.navigation_outlined),
                  label: const Text('Navigate'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PickupScreen extends ConsumerWidget {
  const PickupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pickup management')),
      body: AsyncBody(
        value: ref.watch(ordersProvider),
        onRetry: () => ref.invalidate(ordersProvider),
        builder: (orders) {
          final toLoad = orders.where((o) => o.status == DeliveryStatus.accepted).toList();
          final loaded = orders.where((o) => o.status == DeliveryStatus.pickedUp).toList();
          return ListView(
            padding: AppSpacing.page,
            children: [
              SubMenuCard(
                icon: Icons.factory_outlined,
                title: 'Factory details',
                onTap: () => context.push(Routes.factoryDetails),
              ),
              SubMenuCard(
                icon: Icons.inventory_2_outlined,
                title: 'Pickup quantity',
                onTap: () => context.push(Routes.pickupQuantity),
              ),
              SubMenuCard(
                icon: Icons.fact_check_outlined,
                title: 'Loading confirmation',
                onTap: () => context.push(Routes.loadingConfirmation),
              ),
              SubMenuCard(
                icon: Icons.photo_library_outlined,
                title: 'Pickup photos',
                onTap: () => context.push(Routes.pickupPhotos),
              ),
              SectionTitle('To load (${toLoad.length})'),
              if (toLoad.isEmpty) const Text('Accept an assigned order to load it here.'),
              for (final o in toLoad) _LoadTile(order: o),
              SectionTitle('Loaded, ready to leave (${loaded.length})'),
              if (loaded.isEmpty) const Text('Loaded orders show up here until you start the delivery.'),
              for (final o in loaded)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OrderTile(order: o),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LoadTile extends StatelessWidget {
  const _LoadTile({required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: () => context.push(Routes.loading(order.id)),
        child: Row(
          children: [
            Expanded(child: Text('${order.dealerName}\n${order.number} · ${order.totalUnits} units')),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class FactoryDetailsScreen extends ConsumerWidget {
  const FactoryDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Factory details')),
      body: AsyncBody(
        value: ref.watch(factoryProvider),
        builder: (factory) => ListView(
          padding: AppSpacing.page,
          children: [_FactoryCard(factory: factory)],
        ),
      ),
    );
  }
}

class PickupQuantityScreen extends ConsumerWidget {
  const PickupQuantityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pickup quantity')),
      body: AsyncBody(
        value: ref.watch(ordersProvider),
        builder: (orders) {
          final items = orders.where((o) => o.status == DeliveryStatus.accepted || o.pickup != null).toList();
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Nothing to pick up',
              message: 'Accept an assigned order to see how much to load.',
            );
          }
          return ListView(
            padding: AppSpacing.page,
            children: [
              for (final o in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    onTap: () => context.push(o.pickup == null ? Routes.loading(o.id) : Routes.order(o.id)),
                    child: Column(
                      children: [
                        InfoRow(o.dealerName, o.number),
                        for (final i in o.items)
                          InfoRow(
                            '${i.name} (${i.packSize})',
                            o.pickup == null
                                ? '${i.quantity} ${i.unit} to load'
                                : '${o.loadedOf(i)} of ${i.quantity} ${i.unit} loaded',
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class LoadingConfirmationListScreen extends ConsumerWidget {
  const LoadingConfirmationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loading confirmation')),
      body: AsyncBody(
        value: ref.watch(ordersProvider),
        builder: (orders) {
          final waiting = orders.where((o) => o.status == DeliveryStatus.accepted).toList();
          final confirmed = orders.where((o) => o.pickup != null).toList();
          return ListView(
            padding: AppSpacing.page,
            children: [
              const SectionTitle('Waiting for confirmation'),
              if (waiting.isEmpty) const Text('No orders are waiting to be loaded.'),
              for (final o in waiting) _LoadTile(order: o),
              const SectionTitle('Confirmed'),
              if (confirmed.isEmpty) const Text('Orders you have loaded are listed here.'),
              for (final o in confirmed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    onTap: () => context.push(Routes.order(o.id)),
                    child: Column(
                      children: [
                        InfoRow(o.dealerName, o.number),
                        InfoRow('Loaded at', formatDateTime(o.pickup!.at)),
                        if (o.pickup!.remark.isNotEmpty) InfoRow('Remark', o.pickup!.remark),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class PickupPhotosScreen extends ConsumerWidget {
  const PickupPhotosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pickup photos')),
      body: AsyncBody(
        value: ref.watch(ordersProvider),
        builder: (orders) {
          final items = orders.where((o) => o.pickup?.photos.isNotEmpty ?? false).toList();
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.photo_library_outlined,
              title: 'No pickup photos yet',
              message: 'Photos you take while loading are kept here.',
            );
          }
          return ListView(
            padding: AppSpacing.page,
            children: [
              for (final o in items) ...[
                SectionTitle('${o.dealerName} · ${o.number}'),
                AppCard(child: PhotoGallery(photos: o.pickup!.photos)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class LoadingScreen extends ConsumerStatefulWidget {
  const LoadingScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends ConsumerState<LoadingScreen> {
  final _remark = TextEditingController();
  Map<String, int>? _loaded;
  List<CapturedPhoto> _photos = const [];
  bool _checked = false;
  bool _saving = false;

  @override
  void dispose() {
    _remark.dispose();
    super.dispose();
  }

  bool _isShort(DeliveryOrder order) => order.items.any((i) => (_loaded![i.id] ?? 0) < i.quantity);

  Future<void> _confirm(DeliveryOrder order) async {
    final String? problem = switch (()) {
      _ when _loaded!.values.every((q) => q == 0) => 'Load at least one item, or mark the order as failed',
      _ when _isShort(order) && _remark.text.trim().isEmpty => 'Say why the load is short',
      _ when _photos.isEmpty => 'Please take a photo of the loaded goods',
      _ when !_checked => 'Please confirm you have checked the load',
      _ => null,
    };
    if (problem != null) {
      showMessage(context, problem, isError: true);
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
          .confirmPickup(
            order.id,
            PickupRecord(
              loaded: _loaded!,
              photos: _photos,
              at: DateTime.now(),
              remark: _remark.text.trim(),
              location: location,
            ),
          ),
    );
    if (!mounted) return;
    if (done) {
      showMessage(context, 'Loading confirmed');
      context.pop();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final factory = ref.watch(factoryProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Loading confirmation')),
      body: AsyncBody(
        value: ref.watch(orderProvider(widget.orderId)),
        builder: (order) {
          if (order == null) return const EmptyState(icon: Icons.inventory_2_outlined, title: 'Order not found');
          _loaded ??= {for (final i in order.items) i.id: i.quantity};
          return ListView(
            padding: AppSpacing.page,
            children: [
              Text('${order.dealerName} · ${order.number}', style: Theme.of(context).textTheme.titleSmall),
              if (factory != null) Text('From ${factory.name}'),
              const SectionTitle('Pickup quantity'),
              for (final i in order.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(child: Text('${i.name} (${i.packSize})\nOrdered ${i.quantity} ${i.unit}')),
                        QuantityStepper(
                          value: _loaded![i.id]!,
                          min: 0,
                          max: i.quantity,
                          onChanged: (v) => setState(() => _loaded![i.id] = v),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_isShort(order)) ...[
                const NoticeBanner(
                  'The load is short of the order. The dealer will only be billed for what is delivered.',
                ),
                const SizedBox(height: 8),
                LabeledField(
                  label: 'Why is the load short?',
                  child: TextField(
                    controller: _remark,
                    decoration: InputDecoration(hintText: enterHint('Why is the load short?')),
                  ),
                ),
              ],
              const SectionTitle('Pickup photos'),
              PhotoField(photos: _photos, onChanged: (p) => setState(() => _photos = p)),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _checked,
                activeColor: AppColors.sky700,
                title: const Text('I have checked the count and the ice is in good condition'),
                onChanged: (v) => setState(() => _checked = v ?? false),
              ),
              const SizedBox(height: 8),
              LoadingButton(label: 'Confirm loading', loading: _saving, onPressed: () => _confirm(order)),
            ],
          );
        },
      ),
    );
  }
}
