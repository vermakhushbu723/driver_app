import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../data/api_auth_repository.dart';

import '../../../core/storage/local_store.dart';
import '../data/fake_auth_repository.dart';
import '../domain/rider.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => useFakeBackend ? FakeAuthRepository(ref.watch(localStoreProvider)) : ApiAuthRepository(ref.watch(apiProvider)));

class AuthController extends AsyncNotifier<Rider?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<Rider?> build() => _repo.currentRider();

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
