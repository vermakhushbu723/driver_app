import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/storage/local_store.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/photo_field.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../orders/presentation/delivery_screens.dart';
import '../../returns/domain/return_report.dart';

class _MenuItem {
  const _MenuItem(this.label, this.route);

  final String label;
  final String route;
}

class _MenuSection {
  const _MenuSection(this.icon, this.title, this.items);

  final IconData icon;
  final String title;
  final List<_MenuItem> items;
}

final _sections = [
  _MenuSection(Icons.dashboard_outlined, 'Dashboard', [
    const _MenuItem('Dashboard', Routes.home),
    _MenuItem('Today\'s deliveries', Routes.orderList(OrderFilter.today.name)),
    _MenuItem('Pending deliveries', Routes.orderList(OrderFilter.pending.name)),
    _MenuItem('Completed deliveries', Routes.orderList(OrderFilter.completed.name)),
    const _MenuItem('Today\'s collection', Routes.collection),
  ]),
  _MenuSection(Icons.receipt_long_outlined, 'My orders', [
    _MenuItem('Assigned orders', Routes.orderList(OrderFilter.assigned.name)),
    _MenuItem('Accepted orders', Routes.orderList(OrderFilter.accepted.name)),
    _MenuItem('Picked up orders', Routes.orderList(OrderFilter.pickedUp.name)),
    _MenuItem('Out for delivery', Routes.orderList(OrderFilter.outForDelivery.name)),
    _MenuItem('Delivered orders', Routes.orderList(OrderFilter.delivered.name)),
    _MenuItem('Failed deliveries', Routes.orderList(OrderFilter.failed.name)),
  ]),
  const _MenuSection(Icons.factory_outlined, 'Pickup management', [
    _MenuItem('Factory details', Routes.factoryDetails),
    _MenuItem('Pickup quantity', Routes.pickupQuantity),
    _MenuItem('Loading confirmation', Routes.loadingConfirmation),
    _MenuItem('Pickup photos', Routes.pickupPhotos),
  ]),
  _MenuSection(Icons.local_shipping_outlined, 'Delivery management', [
    _MenuItem('Dealer details', Routes.deliverySection(DeliverySection.dealers.name)),
    _MenuItem('Delivery address', Routes.deliverySection(DeliverySection.addresses.name)),
    _MenuItem('Google Maps navigation', Routes.deliverySection(DeliverySection.navigation.name)),
    _MenuItem('Call dealer', Routes.deliverySection(DeliverySection.call.name)),
    _MenuItem('Delivered quantity', Routes.deliverySection(DeliverySection.quantity.name)),
    _MenuItem('Upload delivery photos', Routes.deliverySection(DeliverySection.photos.name)),
    _MenuItem('Receiver name (optional)', Routes.deliverySection(DeliverySection.receiver.name)),
  ]),
  const _MenuSection(Icons.my_location, 'Live tracking', [
    _MenuItem('Start / stop duty', Routes.duty),
    _MenuItem('Live GPS location', Routes.liveGps),
    _MenuItem('Route tracking', Routes.routeTracking),
  ]),
  const _MenuSection(Icons.payments_outlined, 'Payment collection', [
    _MenuItem('Cash collection', Routes.cashCollection),
    _MenuItem('UPI collection', Routes.upiCollection),
    _MenuItem('Payment history', Routes.paymentHistory),
    _MenuItem('Cash handover', Routes.cashHandover),
  ]),
  _MenuSection(Icons.assignment_return_outlined, 'Return and damage', [
    _MenuItem('Damaged bags', Routes.returns(ReturnType.damagedBags.name)),
    _MenuItem('Melted ice', Routes.returns(ReturnType.meltedIce.name)),
    _MenuItem('Short quantity', Routes.returns(ReturnType.shortQuantity.name)),
    const _MenuItem('Return photos', Routes.returnPhotos),
  ]),
  const _MenuSection(Icons.history, 'My history', [
    _MenuItem('Delivery history', Routes.deliveryHistory),
    _MenuItem('Collection history', Routes.collectionHistory),
  ]),
  const _MenuSection(Icons.badge_outlined, 'Attendance and earnings', [
    _MenuItem('Check in / check out', Routes.attendance),
    _MenuItem('Salary', Routes.salary),
    _MenuItem('Incentives', Routes.incentives),
    _MenuItem('Fuel top-up', Routes.fuel),
  ]),
  const _MenuSection(Icons.notifications_none, 'Notifications', [
    _MenuItem('All notifications', Routes.notifications),
    _MenuItem('Notification settings', Routes.notificationSettings),
  ]),
  const _MenuSection(Icons.support_agent_outlined, 'Help and support', [
    _MenuItem('Call and WhatsApp', Routes.support),
    _MenuItem('My support tickets', Routes.tickets),
    _MenuItem('Raise a support ticket', Routes.newTicket),
  ]),
  const _MenuSection(Icons.person_outline, 'My profile and settings', [
    _MenuItem('My profile', Routes.profile),
    _MenuItem('Vehicle details', Routes.vehicle),
    _MenuItem('Documents', Routes.documents),
    _MenuItem('Change password', Routes.changePassword),
  ]),
];

/// The tab routes that live in the bottom bar, which `go` switches to.
const _tabRoutes = {Routes.home, Routes.orders, Routes.pickup, Routes.collection, Routes.menu};

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Log out?',
      message: 'You can sign back in with your mobile number.',
      confirmLabel: 'Log out',
    );
    if (confirmed) await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rider = ref.watch(authControllerProvider).value;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          if (rider != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              child: AppCard(
                onTap: () => context.push(Routes.profile),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: AppColors.sky100,
                      child: Icon(Icons.delivery_dining, color: AppColors.sky700),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text('${rider.name}\n+91 ${rider.phone}', style: text.labelLarge)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 6),
          for (final (i, section) in _sections.indexed)
            ExpansionTile(
              key: PageStorageKey(section.title),
              leading: Icon(section.icon, color: AppColors.sky700),
              title: Text('${i + 1}. ${section.title}'),
              shape: const Border(),
              collapsedShape: const Border(),
              childrenPadding: const EdgeInsets.only(left: 22),
              children: [
                for (final item in section.items)
                  ListTile(
                    title: Text(item.label),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => _tabRoutes.contains(item.route) ? context.go(item.route) : context.push(item.route),
                  ),
              ],
            ),
          const Divider(height: 20),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.neutral700),
            title: const Text('Logout'),
            onTap: () => _logout(context, ref),
          ),
          const SizedBox(height: 6),
          Center(child: Text(AppConstants.appName, style: text.labelSmall)),
        ],
      ),
    );
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rider = ref.watch(authControllerProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('My profile')),
      body: rider == null
          ? const SizedBox.shrink()
          : ListView(
              padding: AppSpacing.page,
              children: [
                AppCard(
                  child: Column(
                    children: [
                      InfoRow('Name', rider.name),
                      InfoRow('Mobile number', '+91 ${rider.phone}'),
                      InfoRow('Zone', rider.zone),
                      InfoRow('Joined', formatDate(rider.joinedOn)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SubMenuCard(
                  icon: Icons.two_wheeler,
                  title: 'Vehicle details',
                  onTap: () => context.push(Routes.vehicle),
                ),
                SubMenuCard(
                  icon: Icons.badge_outlined,
                  title: 'Documents',
                  onTap: () => context.push(Routes.documents),
                ),
                SubMenuCard(
                  icon: Icons.lock_outline,
                  title: 'Change password',
                  onTap: () => context.push(Routes.changePassword),
                ),
                SubMenuCard(
                  icon: Icons.notifications_none,
                  title: 'Notification settings',
                  onTap: () => context.push(Routes.notificationSettings),
                ),
                const SizedBox(height: 4),
                const NoticeBanner('To change your details, please contact your admin.', color: AppColors.sky600),
              ],
            ),
    );
  }
}

class VehicleScreen extends ConsumerWidget {
  const VehicleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rider = ref.watch(authControllerProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle details')),
      body: rider == null
          ? const SizedBox.shrink()
          : ListView(
              padding: AppSpacing.page,
              children: [
                AppCard(
                  child: Column(
                    children: [
                      InfoRow('Type', rider.vehicleType),
                      InfoRow('Number', rider.vehicleNumber),
                      InfoRow('Licence number', rider.licenceNumber),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

const _documentNames = ['Driving licence', 'Vehicle RC', 'Vehicle insurance', 'Aadhaar card'];

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  static const _key = 'rider_documents';

  LocalStore get _store => ref.read(riderStoreProvider);

  Map<String, String> get _documents => (_store.readMap(_key) ?? const {}).cast<String, String>();

  @override
  void initState() {
    super.initState();
    if (!useFakeBackend) _load();
  }

  Future<void> _save(Map<dynamic, dynamic> documents) async {
    await _store.writeMap(_key, documents.cast<String, dynamic>());
    if (mounted) setState(() {});
  }

  Future<void> _load() async => _save(await ref.read(apiProvider).get('/rider/me/documents') as Map);

  Future<void> _capture(String name) async {
    final photo = await capturePhoto(context, ref);
    if (photo == null) return;
    if (useFakeBackend) {
      await _save({..._documents, name: photo.path});
      return;
    }
    final api = ref.read(apiProvider);
    final url = await api.upload(photo.path);
    await _save(await api.put('/rider/me/documents/${Uri.encodeComponent(name)}', {'path': url}) as Map);
  }

  @override
  Widget build(BuildContext context) {
    final documents = _documents;
    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          for (final name in _documentNames)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          documents.containsKey(name) ? Icons.check_circle : Icons.upload_file_outlined,
                          color: documents.containsKey(name) ? AppColors.green600 : AppColors.sky700,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(name, style: Theme.of(context).textTheme.labelLarge)),
                        TextButton(
                          onPressed: () => _capture(name),
                          child: Text(documents.containsKey(name) ? 'Replace' : 'Take photo'),
                        ),
                      ],
                    ),
                    if (documents.containsKey(name)) ...[
                      const SizedBox(height: 6),
                      LocalImage(documents[name]!, height: 120),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).changePassword(current: _current.text, next: _next.text);
      if (!mounted) return;
      showMessage(context, 'Password updated');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(context, '$e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.page,
          children: [
            LabeledField(
              label: 'Current password',
              child: TextFormField(
                controller: _current,
                obscureText: true,
                validator: Validators.required,
                decoration: InputDecoration(hintText: enterHint('Current password')),
              ),
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: 'New password',
              child: TextFormField(
                controller: _next,
                obscureText: true,
                validator: Validators.password,
                decoration: InputDecoration(
                  hintText: enterHint('New password'),
                  helperText: 'At least 8 characters, with letters and numbers',
                ),
              ),
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: 'Confirm new password',
              child: TextFormField(
                controller: _confirm,
                obscureText: true,
                validator: (v) => v == _next.text ? null : 'Passwords do not match',
                decoration: InputDecoration(hintText: enterHint('Confirm new password')),
              ),
            ),
            const SizedBox(height: 12),
            LoadingButton(label: 'Update password', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
