import '../../../core/network/api_client.dart';
import '../domain/factory_info.dart';

class ApiFactoryRepository implements FactoryRepository {
  ApiFactoryRepository(this._api);

  final ApiClient _api;

  @override
  Future<FactoryInfo> assignedFactory() async {
    final j = await _api.get('/rider/factory') as Map<String, dynamic>;
    return FactoryInfo(name: j['name'] as String, address: j['address'] as String, contactName: j['contactName'] as String, phone: j['phone'] as String, loadingHours: j['loadingHours'] as String, instructions: j['instructions'] as String);
  }
}
