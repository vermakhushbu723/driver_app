import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/api_fuel_repository.dart';
import '../data/fake_fuel_repository.dart';
import '../domain/fuel_top_up.dart';

final fuelRepositoryProvider = Provider<FuelRepository>(
  (ref) => useFakeBackend ? FakeFuelRepository(ref.watch(riderStoreProvider)) : ApiFuelRepository(ref.watch(apiProvider)),
);

final fuelAccountProvider = FutureProvider<FuelAccount>((ref) => ref.watch(fuelRepositoryProvider).account());

/// A clip recorded at the pump. Camera only, so an old video from the gallery can't be used.
class RecordedVideo {
  const RecordedVideo(this.path, this.bytes, this.recordedAt);

  final String path;
  final int bytes;
  final DateTime recordedAt;
}

Future<RecordedVideo?> _recordVideo() async {
  final file = await ImagePicker().pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 45));
  if (file == null) return null;
  return RecordedVideo(file.path, await file.length(), DateTime.now());
}

/// Swapped in tests, where there is no camera.
final videoCaptureProvider = Provider<Future<RecordedVideo?> Function()>((ref) => _recordVideo);

/// The server takes videos up to 60 MB; a 45 second phone clip is well under that.
const _maxVideoBytes = 60 * 1024 * 1024;

class FuelScreen extends ConsumerWidget {
  const FuelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fuel top-up')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(fuelAccountProvider.future),
        child: ListView(
          padding: AppSpacing.page,
          children: [
            const NoticeBanner('At the pump, record a short video showing the meter and the fuel going in. Then enter the amount and send it for approval.'),
            const SizedBox(height: 12),
            const _FuelForm(),
            AsyncBody(
              value: ref.watch(fuelAccountProvider),
              builder: (account) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle('This month'),
                  AppCard(
                    child: Row(
                      children: [
                        Expanded(child: _Figure('Fuel', money(account.month.amount))),
                        Expanded(child: _Figure('Litres', account.month.litres.toStringAsFixed(1))),
                        Expanded(child: _Figure('Top-ups', '${account.month.count}')),
                      ],
                    ),
                  ),
                  const SectionTitle('My fuel top-ups'),
                  if (account.topUps.isEmpty) const Text('No fuel top-ups yet.'),
                  for (final f in account.topUps) _TopUpTile(topUp: f),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: Theme.of(context).textTheme.titleMedium),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ],
  );
}

class _FuelForm extends ConsumerStatefulWidget {
  const _FuelForm();

  @override
  ConsumerState<_FuelForm> createState() => _FuelFormState();
}

class _FuelFormState extends ConsumerState<_FuelForm> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _litres = TextEditingController();
  final _odometer = TextEditingController();
  final _pump = TextEditingController();
  final _note = TextEditingController();
  RecordedVideo? _video;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_amount, _litres, _odometer, _pump, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _record() async {
    try {
      final video = await ref.read(videoCaptureProvider)();
      if (video == null || !mounted) return;
      if (video.bytes > _maxVideoBytes) {
        showMessage(context, 'That video is too long. Record up to 45 seconds.', isError: true);
        return;
      }
      setState(() => _video = video);
    } on PlatformException {
      if (mounted) showMessage(context, 'Please allow camera access for this app in your phone settings, then try again.', isError: true);
    }
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    if (_video == null) {
      showMessage(context, 'Record a video of the fuel being filled', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(fuelRepositoryProvider).send(NewFuelTopUp(
        amount: double.parse(_amount.text.trim()),
        litres: double.parse(_litres.text.trim()),
        odometerKm: int.tryParse(_odometer.text.trim()),
        pump: _pump.text.trim(),
        note: _note.text.trim(),
        videoPath: _video!.path,
      ));
      ref.invalidate(fuelAccountProvider);
      if (!mounted) return;
      showMessage(context, 'Sent for approval');
      _form.currentState!.reset();
      for (final c in [_amount, _litres, _odometer, _pump, _note]) {
        c.clear();
      }
      setState(() => _video = null);
    } catch (e) {
      if (mounted) showMessage(context, '$e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _positive(String? v, String message, {double max = 100000}) {
    final n = double.tryParse(v?.trim() ?? '');
    return n == null || n <= 0 || n > max ? message : null;
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    final decimal = [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,6}(\.\d{0,2})?'))];
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The camera button the rider taps at the pump.
          AppCard(
            onTap: _saving ? null : _record,
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: video == null ? AppColors.sky100 : AppColors.green600.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(video == null ? Icons.videocam_outlined : Icons.check_circle, color: video == null ? AppColors.sky700 : AppColors.green600),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(video == null ? 'Record fuel video' : 'Video recorded', style: Theme.of(context).textTheme.labelLarge),
                      Text(
                        video == null ? 'Opens the camera, up to 45 seconds' : '${(video.bytes / 1024 / 1024).toStringAsFixed(1)} MB at ${formatTime(video.recordedAt)}. Tap to record again.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.local_gas_station_outlined, color: AppColors.sky700),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LabeledField(
                  label: 'Amount (₹)',
                  child: TextFormField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: decimal,
                    decoration: const InputDecoration(hintText: 'Enter amount'),
                    validator: (v) => _positive(v, 'Enter the amount', max: 20000),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LabeledField(
                  label: 'Litres',
                  child: TextFormField(
                    controller: _litres,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: decimal,
                    decoration: const InputDecoration(hintText: 'Enter litres'),
                    validator: (v) => _positive(v, 'Enter the litres', max: 500),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LabeledField(
            label: 'Odometer reading in km (optional)',
            child: TextFormField(
              controller: _odometer,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
              decoration: const InputDecoration(hintText: 'Enter odometer reading'),
            ),
          ),
          const SizedBox(height: 12),
          LabeledField(
            label: 'Petrol pump (optional)',
            child: TextFormField(controller: _pump, maxLength: 120, decoration: const InputDecoration(hintText: 'Enter pump name or area')),
          ),
          LabeledField(
            label: 'Note (optional)',
            child: TextFormField(controller: _note, maxLength: 300, decoration: const InputDecoration(hintText: 'Enter a note for the office')),
          ),
          LoadingButton(label: _saving ? 'Uploading video…' : 'Send for approval', loading: _saving, onPressed: _send),
        ],
      ),
    );
  }
}

class _TopUpTile extends StatelessWidget {
  const _TopUpTile({required this.topUp});

  final FuelTopUp topUp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_gas_station_outlined, size: 18, color: AppColors.sky700),
                const SizedBox(width: 6),
                Expanded(child: Text('${money(topUp.amount)} · ${topUp.litres.toStringAsFixed(1)} L', style: Theme.of(context).textTheme.labelLarge)),
                StatusChip(topUp.status.label, color: topUp.status.color),
              ],
            ),
            const SizedBox(height: 4),
            Text(formatDateTime(topUp.at), style: Theme.of(context).textTheme.bodySmall),
            if (topUp.pump.isNotEmpty || topUp.odometerKm != null)
              Text([if (topUp.pump.isNotEmpty) topUp.pump, if (topUp.odometerKm != null) '${topUp.odometerKm} km'].join(' · '), style: Theme.of(context).textTheme.bodySmall),
            if (topUp.remark.isNotEmpty) Text('Office: ${topUp.remark}', style: const TextStyle(color: AppColors.red600)),
          ],
        ),
      ),
    );
  }
}
