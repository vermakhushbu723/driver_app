import '../../../core/network/api_client.dart';
import '../domain/fuel_top_up.dart';

class ApiFuelRepository implements FuelRepository {
  ApiFuelRepository(this._api);

  final ApiClient _api;

  @override
  Future<FuelAccount> account() async {
    final body = await _api.get('/rider/fuel') as Map<String, dynamic>;
    return FuelAccount((body['topUps'] as Object).mapped(FuelTopUp.fromJson), FuelMonth.fromJson(body['month'] as Map<String, dynamic>));
  }

  @override
  Future<FuelTopUp> send(NewFuelTopUp topUp) async {
    final video = await _api.upload(topUp.videoPath, filename: 'fuel.mp4');
    final body = await _api.post('/rider/fuel', {
      'amount': topUp.amount,
      'litres': topUp.litres,
      'odometerKm': topUp.odometerKm,
      'pump': topUp.pump,
      'note': topUp.note,
      'video': video,
    });
    return FuelTopUp.fromJson(body as Map<String, dynamic>);
  }
}
