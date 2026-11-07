import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../data/api_auth_repository.dart';

import '../../../core/storage/local_store.dart';
import '../data/fake_auth_repository.dart';
import '../domain/rider.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => useFakeBackend ? FakeAuthRepository(ref.watch(localStoreProvider)) : ApiAuthRepository(ref.watch(apiProvider)));

class AuthController extends AsyncNotifier<Rider?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  /// The profile from the last visit, so the app opens at once instead of waiting on the server.
  static const _savedKey = 'signed_in_profile';

  @override
  Future<Rider?> build() async {
    if (useFakeBackend) return _repo.currentRider();
    final store = ref.read(localStoreProvider);
    listenSelf((_, next) {
      if (next.isLoading || next.hasError) return;
      final value = next.value;
      value == null ? store.remove(_savedKey) : store.writeMap(_savedKey, value.toJson());
    });
    final saved = ref.read(apiProvider).hasToken ? store.readMap(_savedKey) : null;
    if (saved == null) return _repo.currentRider();
    // The server's copy follows a moment later; a signed-out or expired session goes to login then.
    Future(() async {
      try {
        final fresh = await _repo.currentRider();
        if (ref.mounted) state = AsyncData(fresh);
      } catch (_) {
        // Offline: keep the saved profile, the screens show their own errors.
      }
    });
    return Rider.fromJson(saved);
  }

  Future<void> verifyOtp(String phone, String otp) async => state = AsyncData(await _repo.verifyOtp(phone, otp));

  Future<void> signInWithPassword(String phone, String password) async =>
      state = AsyncData(await _repo.signInWithPassword(phone, password));

  Future<void> setOnDuty(bool onDuty) async => state = AsyncData(await _repo.setOnDuty(onDuty));

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncData(null);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, Rider?>(AuthController.new);

final riderIdProvider = Provider<String?>((ref) => ref.watch(authControllerProvider.select((a) => a.value?.id)));

/// Storage for the signed-in rider. Every repository built on this one is
/// recreated when the rider changes, which clears their cached data too.
final riderStoreProvider = Provider<LocalStore>((ref) {
  final id = ref.watch(riderIdProvider);
  return ref.watch(localStoreProvider).scoped(id ?? 'signed_out');
});
