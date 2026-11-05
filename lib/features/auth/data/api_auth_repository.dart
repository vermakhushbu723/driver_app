import '../../../core/network/api_client.dart';
import '../domain/rider.dart';

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api);

  final ApiClient _api;

  Future<Rider> _signedIn(dynamic body) async {
    final data = body as Map<String, dynamic>;
    await _api.saveToken(data['token'] as String);
    return Rider.fromJson(data['user'] as Map<String, dynamic>);
  }

  @override
  Future<Rider?> currentRider() async {
    if (!_api.hasToken) return null;
    try {
      return Rider.fromJson(await _api.get('/rider/me') as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.status == 401) return null;
      rethrow;
    }
  }

  @override
  Future<void> sendOtp(String phone) => _api.post('/auth/rider/otp/send', {'phone': phone});

  @override
  Future<Rider> verifyOtp(String phone, String otp) async => _signedIn(await _api.post('/auth/rider/otp/verify', {'phone': phone, 'otp': otp}));

  @override
  Future<Rider> signInWithPassword(String phone, String password) async => _signedIn(await _api.post('/auth/rider/login', {'phone': phone, 'password': password}));

  @override
  Future<void> changePassword({required String current, required String next}) async {
    final body = await _api.post('/rider/me/password', {'current': current, 'next': next}) as Map<String, dynamic>;
    await _api.saveToken(body['token'] as String);
  }

  @override
  Future<Rider> setOnDuty(bool onDuty) async => Rider.fromJson(await _api.put('/rider/me/duty', {'onDuty': onDuty}) as Map<String, dynamic>);

  @override
  Future<void> logout() => _api.clearToken();
}
