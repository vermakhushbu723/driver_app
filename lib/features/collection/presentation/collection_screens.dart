import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../data/api_collection_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../orders/domain/delivery_order.dart';
import '../../orders/presentation/order_providers.dart';
import '../../orders/presentation/order_screens.dart';
import '../data/fake_collection_repository.dart';
import '../domain/collection.dart';

final collectionRepositoryProvider = Provider<CollectionRepository>(
  (ref) => useFakeBackend ? FakeCollectionRepository(ref.watch(riderStoreProvider)) : ApiCollectionRepository(ref.watch(apiProvider)),
);

final collectionSummaryProvider = FutureProvider<CollectionSummary>(
  (ref) => ref.watch(collectionRepositoryProvider).summary(),
);

class _CashCard extends StatelessWidget {
  const _CashCard({required this.summary});

  final CollectionSummary summary;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GradientHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cash in hand', style: text.labelMedium?.copyWith(color: AppColors.neutral900)),
          Text(money(summary.cashInHand), style: text.displaySmall),
          Text(
            'Today\'s collection: ${money(summary.totalOn(DateTime.now()))}',
            style: text.labelMedium?.copyWith(color: AppColors.neutral900),
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final CollectionEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${entry.dealerName}\n${entry.orderNumber}\n${formatDateTime(entry.at)} · ${entry.mode.label}'
                '${entry.reference.isEmpty ? '' : ' · ${entry.reference}'}',
              ),
            ),
            Text(money(entry.amount), style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}

class _DepositCard extends StatelessWidget {
  const _DepositCard({required this.deposit});

  final CashDeposit deposit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Row(
          children: [
            Expanded(child: Text('Handed over · ref. ${deposit.reference}\n${formatDateTime(deposit.at)}')),
            Text(
              money(deposit.amount),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.green600),
            ),
          ],
        ),
      ),
    );
  }
}

class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment collection')),
      body: AsyncBody(
        value: ref.watch(collectionSummaryProvider),
        onRetry: () => ref.invalidate(collectionSummaryProvider),
        builder: (summary) => ListView(
          padding: AppSpacing.page,
          children: [
            _CashCard(summary: summary),
            const SizedBox(height: 10),
            SubMenuCard(
              icon: Icons.payments_outlined,
              title: 'Cash collection',
              onTap: () => context.push(Routes.cashCollection),
            ),
            SubMenuCard(
              icon: Icons.qr_code_2,
              title: 'UPI collection',
              onTap: () => context.push(Routes.upiCollection),
            ),
            SubMenuCard(
              icon: Icons.history,
              title: 'Payment history',
              onTap: () => context.push(Routes.paymentHistory),
            ),
            SubMenuCard(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Cash handover',
              onTap: () => context.push(Routes.cashHandover),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cash or UPI: what is waiting to be collected, then what has been collected.
class CollectionModeScreen extends ConsumerWidget {
  const CollectionModeScreen({super.key, required this.mode});

  final CollectionMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider).value ?? const <DeliveryOrder>[];
    final toCollect = orders.where((o) => o.collectsPayment && o.isPending).toList();
    return Scaffold(
      appBar: AppBar(title: Text('${mode.label} collection')),
      body: AsyncBody(
        value: ref.watch(collectionSummaryProvider),
        builder: (summary) {
          final entries = summary.entries.where((e) => e.mode == mode).toList();
          final total = entries.fold(0.0, (sum, e) => sum + e.amount);
          final today = entries.where((e) => isSameDay(e.at, DateTime.now())).fold(0.0, (sum, e) => sum + e.amount);
          return ListView(
            padding: AppSpacing.page,
            children: [
              AppCard(
                child: Column(
                  children: [
                    InfoRow('Collected today', money(roundMoney(today)), bold: true),
                    InfoRow('Collected in total', money(roundMoney(total))),
                  ],
                ),
              ),
              const SectionTitle('To collect'),
              if (toCollect.isEmpty) const Text('No payments to collect right now.'),
              for (final o in toCollect)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OrderTile(order: o),
                ),
              const SectionTitle('Collected'),
              if (entries.isEmpty) Text('${mode.label} you collect on delivery is listed here.'),
              for (final e in entries) _EntryCard(entry: e),
            ],
          );
        },
      ),
    );
  }
}

class PaymentHistoryScreen extends ConsumerWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment history')),
      body: AsyncBody(
        value: ref.watch(collectionSummaryProvider),
        builder: (summary) {
          if (summary.entries.isEmpty && summary.deposits.isEmpty) {
            return const EmptyState(
              icon: Icons.history,
              title: 'No payments yet',
              message: 'Money you collect and hand over is listed here.',
            );
          }
          return ListView(
            padding: AppSpacing.page,
            children: [
              if (summary.entries.isNotEmpty) const SectionTitle('Collected'),
              for (final e in summary.entries) _EntryCard(entry: e),
              if (summary.deposits.isNotEmpty) const SectionTitle('Handed over'),
              for (final d in summary.deposits) _DepositCard(deposit: d),
            ],
          );
        },
      ),
    );
  }
}

class CollectionHistoryScreen extends ConsumerStatefulWidget {
  const CollectionHistoryScreen({super.key});

  @override
  ConsumerState<CollectionHistoryScreen> createState() => _CollectionHistoryScreenState();
}

class _CollectionHistoryScreenState extends ConsumerState<CollectionHistoryScreen> {
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

  bool _inRange(CollectionEntry e) {
    final range = _range;
    if (range == null) return true;
    return !e.at.isBefore(range.start) && e.at.isBefore(range.end.add(const Duration(days: 1)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection history'),
        actions: [IconButton(tooltip: 'Filter by date', icon: const Icon(Icons.date_range), onPressed: _pickRange)],
      ),
      body: AsyncBody(
        value: ref.watch(collectionSummaryProvider),
        builder: (summary) {
          final entries = summary.entries.where(_inRange).toList();
          double totalOf(CollectionMode mode) =>
              roundMoney(entries.where((e) => e.mode == mode).fold(0.0, (sum, e) => sum + e.amount));
          return ListView(
            padding: AppSpacing.page,
            children: [
              if (_range != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: InputChip(
                    label: Text('${formatDate(_range!.start)} - ${formatDate(_range!.end)}'),
                    onDeleted: () => setState(() => _range = null),
                  ),
                ),
              AppCard(
                child: Column(
                  children: [
                    InfoRow('Cash', money(totalOf(CollectionMode.cash))),
                    InfoRow('UPI', money(totalOf(CollectionMode.upi))),
                    InfoRow(
                      'Total',
                      money(roundMoney(totalOf(CollectionMode.cash) + totalOf(CollectionMode.upi))),
                      bold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (entries.isEmpty) const Text('No collections for this period.'),
              for (final e in entries) _EntryCard(entry: e),
            ],
          );
        },
      ),
    );
  }
}

class CashHandoverScreen extends ConsumerStatefulWidget {
  const CashHandoverScreen({super.key});

  @override
  ConsumerState<CashHandoverScreen> createState() => _CashHandoverScreenState();
}

class _CashHandoverScreenState extends ConsumerState<CashHandoverScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(collectionRepositoryProvider)
          .depositCash(double.parse(_amount.text.trim()), _reference.text.trim());
      ref.invalidate(collectionSummaryProvider);
      _amount.clear();
      _reference.clear();
      if (mounted) showMessage(context, 'Cash handover recorded');
    } catch (e) {
      if (mounted) showMessage(context, '$e', isError: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cash handover')),
      body: AsyncBody(
        value: ref.watch(collectionSummaryProvider),
        builder: (summary) => Form(
          key: _formKey,
          child: ListView(
            padding: AppSpacing.page,
            children: [
              _CashCard(summary: summary),
              const SizedBox(height: 12),
              LabeledField(
                label: 'Amount',
                child: TextFormField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  validator: Validators.positiveAmount,
                  decoration: InputDecoration(hintText: enterHint('Amount'), prefixIcon: fieldPrefix('₹')),
                ),
              ),
              if (summary.cashInHand > 0)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _amount.text = summary.cashInHand.toStringAsFixed(2),
                    child: const Text('Hand over all'),
                  ),
                ),
              const SizedBox(height: 8),
              LabeledField(
                label: 'Receipt or slip number',
                child: TextFormField(
                  controller: _reference,
                  validator: Validators.required,
                  decoration: InputDecoration(hintText: enterHint('Receipt or slip number')),
                ),
              ),
              const SizedBox(height: 12),
              LoadingButton(
                label: 'Record handover',
                loading: _saving,
                onPressed: summary.cashInHand > 0 ? _submit : null,
              ),
              const SectionTitle('Past handovers'),
              if (summary.deposits.isEmpty) const Text('Cash you hand over is listed here.'),
              for (final d in summary.deposits) _DepositCard(deposit: d),
            ],
          ),
        ),
      ),
    );
  }
}
