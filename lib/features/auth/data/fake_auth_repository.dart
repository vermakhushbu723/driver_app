import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/storage/local_store.dart';
import '../domain/rider.dart';

const demoPhone = '9000000001';
const demoOtp = '123456';
const demoPassword = 'Rider@1234';

/// Only the demo rider exists until the Admin Panel can add riders.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(this._store);

  final LocalStore _store;

  static const _riderKey = 'rider';
  static const _sessionKey = 'session';
  static const _passwordKey = 'password';

  // Only stops the password sitting in plain text on the device. In production
  // the server stores and checks passwords.
  String _hash(String password) => sha256.convert(utf8.encode('$demoPhone:$password')).toString();

  bool _passwordMatches(String password) {
    final stored = _store.readMap(_passwordKey);
    return stored == null ? password == demoPassword : stored['hash'] == _hash(password);
  }

  Rider _load() {
    final json = _store.readMap(_riderKey);
    if (json != null) return Rider.fromJson(json);
    return Rider(
      id: 'R-$demoPhone',
      phone: demoPhone,
      name: 'Demo Rider',
      vehicleType: 'Pickup truck',
      vehicleNumber: 'MH 02 AB 1234',
      licenceNumber: 'MH0220200000000',
      zone: 'Andheri',
      joinedOn: DateTime(2026, 1, 15),
      onDuty: false,
    );
  }

  Future<Rider> _signIn(String phone) async {
    final rider = _load();
    await _store.writeMap(_riderKey, rider.toJson());
    await _store.writeMap(_sessionKey, {'phone': phone});
    return rider;
  }

  @override
  Future<Rider?> currentRider() async => _store.readMap(_sessionKey) == null ? null : _load();

  @override
  Future<void> sendOtp(String phone) async {
    await fakeLatency();
    if (phone != demoPhone) throw const AppException('This number is not registered. Please contact your admin.');
  }

  @override
  Future<Rider> verifyOtp(String phone, String otp) async {
    await fakeLatency();
    if (otp != demoOtp) throw const AppException('Incorrect OTP. Please try again.');
    return _signIn(phone);
  }

  @override
  Future<Rider> signInWithPassword(String phone, String password) async {
    await fakeLatency();
    if (phone != demoPhone || !_passwordMatches(password)) {
      throw const AppException('Incorrect mobile number or password.');
    }
    return _signIn(phone);
  }

  @override
  Future<void> changePassword({required String current, required String next}) async {
    await fakeLatency();
    if (!_passwordMatches(current)) throw const AppException('Your current password is incorrect.');
    await _store.writeMap(_passwordKey, {'hash': _hash(next)});
  }

  @override
  Future<Rider> setOnDuty(bool onDuty) async {
    final rider = _load().copyWith(onDuty: onDuty);
    await _store.writeMap(_riderKey, rider.toJson());
    return rider;
  }

  @override
  Future<void> logout() => _store.remove(_sessionKey);
}
