abstract final class Validators {
  static String? required(String? v) => (v == null || v.trim().isEmpty) ? 'This field is required' : null;

  static String? phone(String? v) =>
      RegExp(r'^[6-9]\d{9}$').hasMatch(v?.trim() ?? '') ? null : 'Enter a valid 10-digit mobile number';

  static String? password(String? v) {
    final value = v ?? '';
    if (value.length < 8) return 'Use at least 8 characters';
    if (!value.contains(RegExp(r'[A-Za-z]')) || !value.contains(RegExp(r'\d'))) {
      return 'Use both letters and numbers';
    }
    return null;
  }

  static String? positiveAmount(String? v) {
    final amount = double.tryParse(v?.trim() ?? '');
    return (amount == null || amount <= 0) ? 'Enter a valid amount' : null;
  }
}
