import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../data/api_attendance_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../orders/presentation/order_providers.dart';
import '../../tracking/presentation/tracking_screens.dart';
import '../data/fake_attendance_repository.dart';
import '../domain/attendance.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>(
  (ref) => useFakeBackend ? FakeAttendanceRepository(ref.watch(riderStoreProvider)) : ApiAttendanceRepository(ref.watch(apiProvider)),
);

final attendanceProvider = FutureProvider<List<AttendanceDay>>((ref) => ref.watch(attendanceRepositoryProvider).days());

final earningsRepositoryProvider = Provider<EarningsRepository>(
  (ref) => useFakeBackend ? FakeEarningsRepository(ref.watch(attendanceRepositoryProvider), ref.watch(orderRepositoryProvider)) : ApiEarningsRepository(ref.watch(apiProvider)),
);

final salariesProvider = FutureProvider<List<SalaryMonth>>((ref) {
  ref.watch(attendanceProvider);
  ref.watch(ordersProvider);
  return ref.watch(earningsRepositoryProvider).salaries();
});

final incentivesProvider = FutureProvider<List<IncentiveEntry>>((ref) {
  ref.watch(ordersProvider);
  return ref.watch(earningsRepositoryProvider).incentives();
});

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  bool _saving = false;

  Future<void> _record(Future<void> Function(GeoPoint?) action) async {
    setState(() => _saving = true);
    try {
      await action(await ref.read(locateProvider)());
      ref.invalidate(attendanceProvider);
    } catch (e) {
      if (mounted) showMessage(context, '$e', isError: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _checkOut() async {
    await _record(ref.read(attendanceRepositoryProvider).checkOut);
    // A rider who has finished for the day is no longer on duty.
    if (mounted && (ref.read(authControllerProvider).value?.onDuty ?? false)) await setDuty(ref, false);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Check in / check out')),
      body: AsyncBody(
        value: ref.watch(attendanceProvider),
        builder: (days) {
          final today = days.where((d) => isSameDay(d.checkIn, now)).firstOrNull;
          final thisMonth = days.where((d) => d.checkIn.year == now.year && d.checkIn.month == now.month).length;
          return ListView(
            padding: AppSpacing.page,
            children: [
              GradientHeader(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formatDateShort(now), style: text.labelMedium?.copyWith(color: AppColors.neutral900)),
                    Text(
                      today == null
                          ? 'Not checked in'
                          : today.checkOut == null
                          ? 'Checked in at ${formatTime(today.checkIn)}'
                          : 'Day complete',
                      style: text.titleLarge,
                    ),
                    if (today?.checkOut != null)
                      Text(
                        '${formatTime(today!.checkIn)} - ${formatTime(today.checkOut!)}',
                        style: text.bodyMedium?.copyWith(color: AppColors.neutral900),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (today == null)
                LoadingButton(
                  label: 'Check in',
                  loading: _saving,
                  onPressed: () => _record(ref.read(attendanceRepositoryProvider).checkIn),
                )
              else if (today.checkOut == null)
                LoadingButton(label: 'Check out', loading: _saving, onPressed: _checkOut),
              const SizedBox(height: 8),
              Text('Your GPS location is saved with each check in and check out.', style: text.bodySmall),
              const SectionTitle('This month'),
              AppCard(child: InfoRow('Days present', '$thisMonth')),
              const SectionTitle('Attendance log'),
              if (days.isEmpty) const Text('Your attendance will be listed here.'),
              for (final d in days.take(31))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    child: Column(
                      children: [
                        InfoRow(formatDateShort(d.checkIn), _hours(d.workedUntil(now))),
                        InfoRow('In', '${formatTime(d.checkIn)}${_at(d.checkInLocation)}'),
                        InfoRow(
                          'Out',
                          d.checkOut == null ? 'Not yet' : '${formatTime(d.checkOut!)}${_at(d.checkOutLocation)}',
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

  String _at(GeoPoint? location) => location == null ? '' : ' · ${location.label}';

  String _hours(Duration d) => '${d.inHours}h ${d.inMinutes.remainder(60)}m';
}

class SalaryScreen extends ConsumerWidget {
  const SalaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Salary')),
      body: AsyncBody(
        value: ref.watch(salariesProvider),
        builder: (months) => ListView(
          padding: AppSpacing.page,
          children: [
            const NoticeBanner('Demo: these are sample figures. The company\'s real pay data will show here later.'),
            const SizedBox(height: 10),
            GradientHeader(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${formatMonthYear(months.first.month)}, so far',
                    style: text.labelMedium?.copyWith(color: AppColors.neutral900),
                  ),
                  Text(money(roundMoney(months.first.net)), style: text.displaySmall),
                ],
              ),
            ),
            for (final m in months) ...[
              SectionTitle(formatMonthYear(m.month)),
              AppCard(
                child: Column(
                  children: [
                    InfoRow('Monthly salary', money(m.baseSalary)),
                    InfoRow('Days present', '${m.presentDays} of ${m.workingDays}'),
                    InfoRow('Earned for days worked', money(roundMoney(m.earned))),
                    InfoRow('Incentives', money(m.incentives)),
                    InfoRow('Deductions', '- ${money(m.deductions)}'),
                    const Divider(height: 16),
                    InfoRow('Net pay', money(roundMoney(m.net)), bold: true),
                    InfoRow(
                      'Status',
                      m.paidOn == null ? 'In progress' : 'Paid on ${formatDate(m.paidOn!)}',
                      valueColor: m.paidOn == null ? AppColors.amber600 : AppColors.green600,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class IncentivesScreen extends ConsumerWidget {
  const IncentivesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Incentives')),
      body: AsyncBody(
        value: ref.watch(incentivesProvider),
        builder: (items) {
          final earned = items.where((i) => i.achieved).fold(0.0, (sum, i) => sum + i.amount);
          return ListView(
            padding: AppSpacing.page,
            children: [
              const NoticeBanner('Demo: these are sample incentive rules. The company will set the real ones.'),
              const SizedBox(height: 10),
              GradientHeader(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Earned this month', style: text.labelMedium?.copyWith(color: AppColors.neutral900)),
                    Text(money(earned), style: text.displaySmall),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              for (final i in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    child: Row(
                      children: [
                        Icon(
                          i.achieved ? Icons.check_circle : Icons.flag_outlined,
                          color: i.achieved ? AppColors.green600 : AppColors.sky700,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(i.title, style: text.labelLarge),
                              Text(i.detail),
                            ],
                          ),
                        ),
                        Text(money(i.amount), style: text.labelLarge),
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
