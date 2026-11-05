import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../data/api_support_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/contact_launcher.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/fake_support_repository.dart';
import '../domain/ticket.dart';

final supportRepositoryProvider = Provider<SupportRepository>(
  (ref) => useFakeBackend ? FakeSupportRepository(ref.watch(riderStoreProvider)) : ApiSupportRepository(ref.watch(apiProvider)),
);

final ticketsProvider = FutureProvider<List<Ticket>>((ref) => ref.watch(supportRepositoryProvider).tickets());

const _faqs = [
  (
    'The dealer has no delivery OTP',
    'Ask the dealer to open the order in their app. If they still can\'t find it, call ICECLUB.',
  ),
  (
    'A delivery can\'t be completed',
    'Open the order, tap Could not deliver, choose a reason and bring the stock back to the factory.',
  ),
  (
    'The factory loaded less than the order',
    'Enter the actual quantity in Loading confirmation and say why. The dealer pays only for what is delivered.',
  ),
  (
    'Bags were damaged or the ice melted',
    'Report it under Return and damage with a photo, and bring the stock back to the factory.',
  ),
  ('Where do I hand over cash?', 'Hand it to the factory cashier, then record the slip number in Cash handover.'),
];

const _categories = [
  'Order or delivery',
  'Pickup or loading',
  'Payment or cash',
  'Vehicle',
  'Salary or attendance',
  'Other',
];

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help and support')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.green600),
            onPressed: () => ContactLauncher.whatsapp(message: 'Hello, I am a rider and I need help.'),
            icon: const Icon(Icons.chat_outlined),
            label: const Text('WhatsApp support'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => ContactLauncher.call(AppConstants.supportPhone),
            icon: const Icon(Icons.call_outlined),
            label: const Text('Call ICECLUB'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push(Routes.tickets),
            icon: const Icon(Icons.support_agent_outlined),
            label: const Text('Raise a support ticket'),
          ),
          const SectionTitle('Frequently asked questions'),
          for (final (question, answer) in _faqs)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 12),
              expandedAlignment: Alignment.centerLeft,
              title: Text(question, style: Theme.of(context).textTheme.labelLarge),
              children: [Text(answer)],
            ),
        ],
      ),
    );
  }
}

class TicketsScreen extends ConsumerWidget {
  const TicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('My support requests')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.newTicket),
        icon: const Icon(Icons.add),
        label: const Text('New request'),
      ),
      body: AsyncBody(
        value: ref.watch(ticketsProvider),
        builder: (tickets) => tickets.isEmpty
            ? const EmptyState(icon: Icons.support_agent_outlined, title: 'No support requests')
            : ListView.separated(
                padding: AppSpacing.pageWithFab,
                itemCount: tickets.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final t = tickets[i];
                  return AppCard(
                    onTap: () => context.push(Routes.ticket(t.id)),
                    child: Row(
                      children: [
                        Expanded(child: Text('${t.subject}\n${t.category} · ${formatDate(t.createdAt)}')),
                        _TicketStatusChip(t.status),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _TicketStatusChip extends StatelessWidget {
  const _TicketStatusChip(this.status);

  final TicketStatus status;

  @override
  Widget build(BuildContext context) =>
      status == TicketStatus.open ? const StatusChip('Open') : const StatusChip('Resolved', color: AppColors.green600);
}

class NewTicketScreen extends ConsumerStatefulWidget {
  const NewTicketScreen({super.key, this.orderNumber});

  final String? orderNumber;

  @override
  ConsumerState<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends ConsumerState<NewTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  late String _category = widget.orderNumber == null ? _categories.last : _categories.first;
  bool _saving = false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await ref
        .read(supportRepositoryProvider)
        .create(
          subject: _subject.text.trim(),
          category: _category,
          message: _message.text.trim(),
          orderNumber: widget.orderNumber,
        );
    ref.invalidate(ticketsProvider);
    if (!mounted) return;
    showMessage(context, 'Your request has been sent');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New support request')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.page,
          children: [
            if (widget.orderNumber != null) ...[InfoRow('Order', widget.orderNumber!), const SizedBox(height: 8)],
            LabeledField(
              label: 'Category',
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                style: Theme.of(context).textTheme.bodyLarge,
                initialValue: _category,
                decoration: InputDecoration(hintText: selectHint('Category')),
                items: [for (final c in _categories) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (v) => setState(() => _category = v!),
              ),
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: 'Subject',
              child: TextFormField(
                controller: _subject,
                validator: Validators.required,
                decoration: InputDecoration(hintText: enterHint('Subject')),
              ),
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: 'Tell us what happened',
              child: TextFormField(
                controller: _message,
                validator: Validators.required,
                maxLines: 5,
                decoration: InputDecoration(hintText: enterHint('Tell us what happened')),
              ),
            ),
            const SizedBox(height: 12),
            LoadingButton(label: 'Send', loading: _saving, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}

class TicketDetailScreen extends ConsumerStatefulWidget {
  const TicketDetailScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  final _reply = TextEditingController();

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _reply.text.trim();
    if (message.isEmpty) return;
    await ref.read(supportRepositoryProvider).reply(widget.ticketId, message);
    _reply.clear();
    ref.invalidate(ticketsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final ticket = ref.watch(ticketsProvider).value?.where((t) => t.id == widget.ticketId).firstOrNull;
    if (ticket == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final isOpen = ticket.status == TicketStatus.open;
    return Scaffold(
      appBar: AppBar(
        title: Text(ticket.subject),
        actions: [
          if (isOpen)
            TextButton(
              onPressed: () async {
                await ref.read(supportRepositoryProvider).resolve(ticket.id);
                ref.invalidate(ticketsProvider);
              },
              child: const Text('Mark resolved'),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: AppSpacing.page,
              children: [
                if (ticket.orderNumber != null)
                  Text('Order ${ticket.orderNumber}', style: Theme.of(context).textTheme.labelMedium),
                for (final m in ticket.messages)
                  Align(
                    alignment: m.fromRider ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
                      decoration: BoxDecoration(
                        color: m.fromRider ? AppColors.sky100 : Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.text),
                          Text(formatDateTime(m.at), style: Theme.of(context).textTheme.labelSmall),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isOpen)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _reply,
                        decoration: const InputDecoration(hintText: 'Enter your reply', isDense: true),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Send',
                      icon: const Icon(Icons.send, color: AppColors.sky600),
                      onPressed: _send,
                    ),
                  ],
                ),
              ),
            )
          else
            const SafeArea(
              child: Padding(padding: EdgeInsets.all(16), child: Text('This request has been resolved.')),
            ),
        ],
      ),
    );
  }
}
