import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';

/// The OTP the server gave back while no SMS provider is connected. A new random code every time.
class ShownOtp {
  const ShownOtp(this.phone, this.code);

  final String phone;
  final String code;
}

class ShownOtpController extends Notifier<ShownOtp?> {
  @override
  ShownOtp? build() => null;

  /// [code] is null once OTPs are sent by SMS; then nothing is shown.
  void show(String phone, String? code) => state = code == null ? null : ShownOtp(phone, code);

  void clear() => state = null;
}

final shownOtpProvider = NotifierProvider<ShownOtpController, ShownOtp?>(ShownOtpController.new);

/// A message at the top of the OTP screen, like an SMS arriving, with the code and a button to fill it in.
class OtpMessage extends StatelessWidget {
  const OtpMessage({super.key, required this.code, required this.onUse});

  final String code;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return TweenAnimationBuilder<double>(
      key: ValueKey(code),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, -24 * (1 - t)), child: child)),
      child: Material(
        color: Colors.white,
        elevation: 3,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(color: AppColors.sky100, shape: BoxShape.circle),
                child: const Icon(Icons.sms_outlined, size: 20, color: AppColors.sky700),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('ICECLUB · now', style: text.labelSmall?.copyWith(color: AppColors.neutral500)),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Your ICECLUB OTP is '),
                          TextSpan(text: code, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5, color: AppColors.neutral900)),
                          const TextSpan(text: '. Valid for 10 minutes. Do not share it with anyone.'),
                        ],
                      ),
                      key: const ValueKey('otp-message'),
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: onUse, child: const Text('Use')),
            ],
          ),
        ),
      ),
    );
  }
}
