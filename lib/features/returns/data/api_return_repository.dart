import '../../../core/network/api_client.dart';
import '../../../core/widgets/photo_field.dart';
import '../domain/return_report.dart';

class ApiReturnRepository implements ReturnRepository {
  ApiReturnRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<ReturnReport>> reports() async => (await _api.get('/rider/returns') as Object).mapped(ReturnReport.fromJson);

  @override
  Future<void> submit(ReturnReport report) async {
    final photos = [for (final p in report.photos) CapturedPhoto(await _api.upload(p.path), p.takenAt).toJson()];
    await _api.post('/rider/returns', {...report.toJson(), 'photos': photos});
  }
}
